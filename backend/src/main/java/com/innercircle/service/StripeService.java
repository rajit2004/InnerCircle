package com.innercircle.service;

import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.stripe.Stripe;
import com.stripe.exception.StripeException;
import com.stripe.model.Customer;
import com.stripe.model.Subscription;
import com.stripe.model.checkout.Session;
import com.stripe.param.CustomerCreateParams;
import com.stripe.param.checkout.SessionCreateParams;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class StripeService {

    private final UserRepository userRepository;

    @Value("${stripe.secret-key:}")
    private String secretKey;

    @Value("${stripe.webhook-secret:}")
    private String webhookSecret;

    @Value("${stripe.success-url:}")
    private String successUrl;

    @Value("${stripe.cancel-url:}")
    private String cancelUrl;

    @Value("${stripe.premium-price-id:}")
    private String premiumPriceId;

    private void initStripe() {
        if (secretKey != null && !secretKey.isEmpty()) {
            Stripe.apiKey = secretKey;
        } else {
            throw new IllegalStateException("Stripe secret key not configured");
        }
    }

    public String getOrCreateCustomer(User user) {
        if (user.getStripeCustomerId() != null && !user.getStripeCustomerId().isEmpty()) {
            return user.getStripeCustomerId();
        }
        initStripe();
        try {
            CustomerCreateParams params = CustomerCreateParams.builder()
                    .setEmail(user.getEmail())
                    .build();
            Customer customer = Customer.create(params);
            user.setStripeCustomerId(customer.getId());
            userRepository.save(user);
            return customer.getId();
        } catch (StripeException e) {
            log.error("Failed to create Stripe customer for user {}", user.getId(), e);
            throw new RuntimeException("Failed to create Stripe customer", e);
        }
    }

    public com.innercircle.dto.CheckoutSessionResponse createCheckoutSession(User user, String priceId) {
        initStripe();
        String customerId = getOrCreateCustomer(user);
        try {
            SessionCreateParams params = SessionCreateParams.builder()
                    .setCustomer(customerId)
                    .setMode(SessionCreateParams.Mode.SUBSCRIPTION)
                    .setSuccessUrl(successUrl + "?session_id={CHECKOUT_SESSION_ID}")
                    .setCancelUrl(cancelUrl)
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setPrice(priceId)
                                    .setQuantity(1L)
                                    .build())
                    .build();
            Session session = Session.create(params);
            return new com.innercircle.dto.CheckoutSessionResponse(session.getId(), session.getUrl());
        } catch (StripeException e) {
            log.error("Failed to create checkout session for user {}", user.getId(), e);
            throw new RuntimeException("Failed to create checkout session", e);
        }
    }

    public com.innercircle.dto.PortalSessionResponse createPortalSession(User user, String returnUrl) {
        initStripe();
        if (user.getStripeCustomerId() == null || user.getStripeCustomerId().isEmpty()) {
            throw new IllegalStateException("User has no Stripe customer ID");
        }
        try {
            com.stripe.param.billingportal.SessionCreateParams params = com.stripe.param.billingportal.SessionCreateParams.builder()
                    .setCustomer(user.getStripeCustomerId())
                    .setReturnUrl(returnUrl)
                    .build();
            com.stripe.model.billingportal.Session session = com.stripe.model.billingportal.Session.create(params);
            return new com.innercircle.dto.PortalSessionResponse(session.getUrl());
        } catch (StripeException e) {
            log.error("Failed to create portal session for user {}", user.getId(), e);
            throw new RuntimeException("Failed to create portal session", e);
        }
    }

    public void handleCheckoutCompleted(com.stripe.model.checkout.Session session) {
        String userIdStr = session.getMetadata().get("userId");
        if (userIdStr == null) {
            log.warn("Checkout session missing userId metadata: {}", session.getId());
            return;
        }
        try {
            java.util.UUID userId = java.util.UUID.fromString(userIdStr);
            User user = userRepository.findById(userId).orElse(null);
            if (user == null) {
                log.warn("User not found for checkout session: {}", session.getId());
                return;
            }
            String subscriptionId = session.getSubscription();
            if (subscriptionId != null) {
                user.setStripeSubscriptionId(subscriptionId);
                user.setSubscriptionTier(com.innercircle.model.SubscriptionTier.premium);
                userRepository.save(user);
                log.info("User {} upgraded to premium via Stripe checkout", userId);
            }
        } catch (Exception e) {
            log.error("Failed to process checkout completion for session {}", session.getId(), e);
        }
    }

    public void handleSubscriptionUpdated(Subscription subscription) {
        String customerId = subscription.getCustomer();
        if (customerId == null) return;
        User user = userRepository.findByStripeCustomerId(customerId).orElse(null);
        if (user == null) {
            log.warn("User not found for Stripe customer: {}", customerId);
            return;
        }
        String status = subscription.getStatus();
        if ("active".equals(status) || "trialing".equals(status)) {
            user.setSubscriptionTier(com.innercircle.model.SubscriptionTier.premium);
            user.setStripeSubscriptionId(subscription.getId());
        } else {
            user.setSubscriptionTier(com.innercircle.model.SubscriptionTier.free);
            user.setStripeSubscriptionId(null);
        }
        userRepository.save(user);
        log.info("User {} subscription updated to {}: {}", user.getId(), status, subscription.getId());
    }

    public void handleSubscriptionDeleted(Subscription subscription) {
        String customerId = subscription.getCustomer();
        if (customerId == null) return;
        User user = userRepository.findByStripeCustomerId(customerId).orElse(null);
        if (user == null) {
            log.warn("User not found for Stripe customer: {}", customerId);
            return;
        }
        user.setSubscriptionTier(com.innercircle.model.SubscriptionTier.free);
        user.setStripeSubscriptionId(null);
        userRepository.save(user);
        log.info("User {} subscription deleted: {}", user.getId(), subscription.getId());
    }

    public String getWebhookSecret() {
        return webhookSecret;
    }

    public String getPremiumPriceId() {
        return premiumPriceId;
    }
}