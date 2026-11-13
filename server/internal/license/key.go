// Package license implements key generation, hashing, encryption at rest, and
// Ed25519 signing of the license envelopes the apps verify offline.
package license

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"strings"
)

// Alphabet is Crockford-style Base32 without the ambiguous characters 0, O, 1,
// and I. Keys are read aloud, typed by hand, and pasted from email, so every
// character has to survive that trip.
const Alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

const (
	// Groups and GroupLen define the key shape: PREFIX-XXXXX-XXXXX-XXXXX-XXXXX.
	Groups   = 4
	GroupLen = 5
)

// Normalize strips separators and case so a key typed with spaces, lowercase,
// or the wrong dash still resolves to the same license.
func Normalize(key string) string {
	var b strings.Builder
	b.Grow(len(key))
	for _, r := range strings.ToUpper(strings.TrimSpace(key)) {
		if (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// Hash returns the hex SHA-256 of the normalized key. Only this value is used
// for lookup; a database dump does not hand out working keys.
func Hash(key string) string {
	sum := sha256.Sum256([]byte(Normalize(key)))
	return hex.EncodeToString(sum[:])
}

// Hint returns the last group, useful for support ("the key ending in 7KQ2M")
// without storing anything that can be used to activate.
func Hint(key string) string {
	normalized := Normalize(key)
	if len(normalized) <= GroupLen {
		return normalized
	}
	return normalized[len(normalized)-GroupLen:]
}

// Generate builds a new key for the given prefix. The prefix is sanitised to
// the key alphabet and padded to four characters.
func Generate(prefix string) (string, error) {
	prefix = sanitizePrefix(prefix)
	groups := make([]string, 0, Groups+1)
	groups = append(groups, prefix)
	for g := 0; g < Groups; g++ {
		group, err := randomGroup(GroupLen)
		if err != nil {
			return "", err
		}
		groups = append(groups, group)
	}
	return strings.Join(groups, "-"), nil
}

func sanitizePrefix(prefix string) string {
	var b strings.Builder
	for _, r := range strings.ToUpper(prefix) {
		if strings.ContainsRune(Alphabet, r) {
			b.WriteRune(r)
		}
		if b.Len() == 4 {
			break
		}
	}
	for b.Len() < 4 {
		b.WriteByte('X')
	}
	return b.String()
}

func randomGroup(n int) (string, error) {
	limit := big.NewInt(int64(len(Alphabet)))
	var b strings.Builder
	b.Grow(n)
	for i := 0; i < n; i++ {
		index, err := rand.Int(rand.Reader, limit)
		if err != nil {
			return "", err
		}
		b.WriteByte(Alphabet[index.Int64()])
	}
	return b.String(), nil
}

// Encrypt seals a plaintext key with AES-256-GCM so the admin dashboard can
// resend or recover a key without keeping plaintext in SQLite. The key is
// derived from a server-side secret; if that secret changes, old ciphertexts
// become unreadable and recovery falls back to reissuing.
func Encrypt(secret []byte, plaintext string) (string, error) {
	if len(secret) == 0 {
		return "", errors.New("license: empty encryption secret")
	}
	block, err := aes.NewCipher(deriveKey(secret))
	if err != nil {
		return "", err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	sealed := aead.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.RawURLEncoding.EncodeToString(sealed), nil
}

// Decrypt opens ciphertext produced by Encrypt.
func Decrypt(secret []byte, ciphertext string) (string, error) {
	if len(secret) == 0 {
		return "", errors.New("license: empty encryption secret")
	}
	raw, err := base64.RawURLEncoding.DecodeString(ciphertext)
	if err != nil {
		return "", fmt.Errorf("license: decode ciphertext: %w", err)
	}
	block, err := aes.NewCipher(deriveKey(secret))
	if err != nil {
		return "", err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < aead.NonceSize() {
		return "", errors.New("license: ciphertext too short")
	}
	nonce, body := raw[:aead.NonceSize()], raw[aead.NonceSize():]
	plain, err := aead.Open(nil, nonce, body, nil)
	if err != nil {
		return "", fmt.Errorf("license: decrypt: %w", err)
	}
	return string(plain), nil
}

func deriveKey(secret []byte) []byte {
	sum := sha256.Sum256(append([]byte("mullion-license-key-v1\x00"), secret...))
	return sum[:]
}
