package src.main.java.com.innercircle.service;

import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Locale;
import java.util.StringJoiner;

/**
 * Lightweight, dependency-free embedding generator.
 *
 * This is a feature-hashing (bag-of-words) embedding: each word in the text
 * is hashed into one of 1536 buckets, and the resulting vector is L2-normalized.
 * It's good enough to power pgvector similarity search for memories that share
 * vocabulary ("loves hiking" vs "went hiking again"), but it is NOT a semantic
 * embedding model -- it won't catch paraphrases with no shared words.
 *
 * Why this exists instead of a real embedding model: Groq (the LLM provider
 * already used for chat) does not currently offer an embeddings endpoint.
 * Swap this for OpenAI's text-embedding-3-small, Cohere, or a self-hosted
 * sentence-transformers model when you want genuine semantic recall -- the
 * call sites (MemoryService, MemoryRepository) don't need to change, only
 * what's inside embed().
 */
@Service
public class EmbeddingService {

    public static final int DIMENSIONS = 1536;

    public float[] embed(String text) {
        float[] vector = new float[DIMENSIONS];
        if (text == null || text.isBlank()) {
            return vector;
        }

        String normalized = text.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9 ]", " ");
        String[] words = normalized.split("\\s+");

        for (String word : words) {
            if (word.isBlank()) continue;
            int bucket = bucketFor(word);
            vector[bucket] += 1.0f;
        }

        normalize(vector);
        return vector;
    }

    /** pgvector accepts vector literals as text, e.g. "[0.1,0.2,...]". */
    public String toPgVectorLiteral(float[] vector) {
        StringJoiner joiner = new StringJoiner(",", "[", "]");
        for (float v : vector) {
            joiner.add(String.valueOf(v));
        }
        return joiner.toString();
    }

    private int bucketFor(String word) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(word.getBytes(StandardCharsets.UTF_8));
            int h = ((hash[0] & 0xFF) << 24) | ((hash[1] & 0xFF) << 16)
                    | ((hash[2] & 0xFF) << 8) | (hash[3] & 0xFF);
            return Math.abs(h) % DIMENSIONS;
        } catch (NoSuchAlgorithmException e) {
            return Math.abs(word.hashCode()) % DIMENSIONS;
        }
    }

    private void normalize(float[] vector) {
        double sumSquares = 0;
        for (float v : vector) sumSquares += (double) v * v;
        double norm = Math.sqrt(sumSquares);
        if (norm == 0) return;
        for (int i = 0; i < vector.length; i++) {
            vector[i] = (float) (vector[i] / norm);
        }
    }
}
