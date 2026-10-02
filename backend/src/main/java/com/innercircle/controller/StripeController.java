package com.innercircle.controller;

import com.innercircle.dto.CheckoutSessionResponse;
import com.innercircle.dto.CreateCheckoutSessionRequest;
import com.innercircle.dto.CreatePortalSessionRequest;
import com.innercircle.dto.PortalSessionResponse;
import com.innercircle.model.User;
import com.innercircle.service.StripeService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/billing")
@RequiredArgsConstructor
@Slf4j
public class StripeController {

    private final StripeService stripeService;

    @PostMapping("/checkout")
    public CheckoutSessionResponse createCheckoutSession(
            @AuthenticationPrincipal User user,
            @RequestBody CreateCheckoutSessionRequest request) {
        String priceId = request.getPriceId() != null ? request.getPriceId() : stripeService.getPremiumPriceId();
        if (priceId == null || priceId.isEmpty()) {
            throw new IllegalStateException("Premium price ID not configured");
        }
        return stripeService.createCheckoutSession(user, priceId);
    }

    @PostMapping("/portal")
    public PortalSessionResponse createPortalSession(
            @AuthenticationPrincipal User user,
            @RequestBody CreatePortalSessionRequest request) {
        return stripeService.createPortalSession(user, request.getReturnUrl());
    }

    @PostMapping("/webhook")
    public ResponseEntity<Void> handleWebhook(
            HttpServletRequest request,
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {
        try {
            String webhookSecret = stripeService.getWebhookSecret();
            if (webhookSecret == null || webhookSecret.isEmpty()) {
                log.warn("Stripe webhook secret not configured");
                return ResponseEntity.badRequest().build();
            }
            com.stripe.model.Event event = com.stripe.net.Webhook.constructEvent(payload, sigHeader, webhookSecret);
            switch (event.getType()) {
                case "checkout.session.completed":
                    log.info("Processing checkout.session.completed: {}", event.getId());
                    com.stripe.model.checkout.Session session =
                            (com.stripe.model.checkout.Session) event.getData().getObject();
                    stripeService.handleCheckoutCompleted(session);
                    break;
                case "customer.subscription.updated":
                    log.info("Processing customer.subscription.updated: {}", event.getId());
                    com.stripe.model.Subscription subUpdated =
                            (com.stripe.model.Subscription) event.getData().getObject();
                    stripeService.handleSubscriptionUpdated(subUpdated);
                    break;
                case "customer.subscription.deleted":
                    log.info("Processing customer.subscription.deleted: {}", event.getId());
                    com.stripe.model.Subscription subDeleted =
                            (com.stripe.model.Subscription) event.getData().getObject();
                    stripeService.handleSubscriptionDeleted(subDeleted);
                    break;
                default:
                    log.debug("Unhandled Stripe event type: {}", event.getType());
            }
            return ResponseEntity.ok().build();
        } catch (com.stripe.exception.SignatureVerificationException e) {
            log.warn("Invalid Stripe signature: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Stripe webhook error", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/config")
    public ResponseEntity<Map<String, String>> getConfig() {
        String priceId = stripeService.getPremiumPriceId();
        return ResponseEntity.ok(Map.of(
                "premiumPriceId", priceId != null ? priceId : "",
                "stripePublishableKey", System.getenv().getOrDefault("STRIPE_PUBLISHABLE_KEY", "")
        ));
    }
}