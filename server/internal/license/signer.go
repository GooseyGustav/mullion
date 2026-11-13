package license

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"strings"
)

// TokenPrefix versions the signed envelope. Every product uses the same prefix;
// the product field identifies the app, so one verifier works for all of them.
const TokenPrefix = "LIC1"

// Claims is the payload embedded in a signed license envelope.
//
// Keep this struct additive. Apps ignore unknown fields, so new claims can ship
// without breaking older builds. Never rename or repurpose an existing field.
type Claims struct {
	V         int     `json:"v"`
	KID       string  `json:"kid"`
	LicenseID string  `json:"license_id"`
	Product   string  `json:"product"`
	Plan      string  `json:"plan"`
	Status    string  `json:"status"`
	Seats     int     `json:"seats"`
	Major     int     `json:"major"`
	IssuedAt  string  `json:"issued_at"`
	ExpiresAt *string `json:"expires_at"`
	InstallID string  `json:"install_id,omitempty"`
	KeyHint   string  `json:"key_hint,omitempty"`
}

// Signer holds the Ed25519 private key. It lives only on the server.
type Signer struct {
	kid  string
	priv ed25519.PrivateKey
}

// NewSigner generates a new keypair.
func NewSigner(kid string) (*Signer, error) {
	if kid == "" {
		return nil, errors.New("license: empty key id")
	}
	_, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("license: generate key: %w", err)
	}
	return &Signer{kid: kid, priv: priv}, nil
}

// LoadSigner reads a PKCS#8 PEM private key, or a raw base64 Ed25519 key (32-byte
// seed or 64-byte private key). The PEM form is preferred because it survives
// password managers and OpenSSL tooling.
func LoadSigner(path, kid string) (*Signer, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("license: read signing key: %w", err)
	}
	return ParseSigner(data, kid)
}

// ParseSigner is LoadSigner without the file read, used by tests and tooling.
func ParseSigner(data []byte, kid string) (*Signer, error) {
	if kid == "" {
		return nil, errors.New("license: empty key id")
	}
	trimmed := strings.TrimSpace(string(data))
	if strings.HasPrefix(trimmed, "-----BEGIN") {
		block, _ := pem.Decode([]byte(trimmed))
		if block == nil {
			return nil, errors.New("license: invalid PEM block")
		}
		key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err != nil {
			return nil, fmt.Errorf("license: parse PKCS#8 key: %w", err)
		}
		priv, ok := key.(ed25519.PrivateKey)
		if !ok {
			return nil, errors.New("license: key is not Ed25519")
		}
		return &Signer{kid: kid, priv: priv}, nil
	}

	raw, err := decodeBase64(trimmed)
	if err != nil {
		return nil, fmt.Errorf("license: decode key: %w", err)
	}
	switch len(raw) {
	case ed25519.SeedSize:
		return &Signer{kid: kid, priv: ed25519.NewKeyFromSeed(raw)}, nil
	case ed25519.PrivateKeySize:
		return &Signer{kid: kid, priv: ed25519.PrivateKey(raw)}, nil
	default:
		return nil, fmt.Errorf("license: unexpected key length %d", len(raw))
	}
}

func decodeBase64(s string) ([]byte, error) {
	for _, enc := range []*base64.Encoding{
		base64.StdEncoding,
		base64.RawStdEncoding,
		base64.URLEncoding,
		base64.RawURLEncoding,
	} {
		if raw, err := enc.DecodeString(s); err == nil {
			return raw, nil
		}
	}
	return nil, errors.New("not base64")
}

// Save writes the private key as PKCS#8 PEM with 0600 permissions.
func (s *Signer) Save(path string) error {
	der, err := x509.MarshalPKCS8PrivateKey(s.priv)
	if err != nil {
		return fmt.Errorf("license: marshal key: %w", err)
	}
	block := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
	if block == nil {
		return errors.New("license: encode PEM")
	}
	if err := os.WriteFile(path, block, 0o600); err != nil {
		return fmt.Errorf("license: write key: %w", err)
	}
	return nil
}

// KID returns the key id embedded in envelopes.
func (s *Signer) KID() string { return s.kid }

// PublicKey returns the raw public key.
func (s *Signer) PublicKey() ed25519.PublicKey {
	return s.priv.Public().(ed25519.PublicKey)
}

// PublicKeyBase64URL is what the app embeds and what /v1/public-key returns.
func (s *Signer) PublicKeyBase64URL() string {
	return base64.RawURLEncoding.EncodeToString(s.PublicKey())
}

// Sign returns LIC1.<payload_b64url>.<sig_b64url>. The signature covers the exact
// base64url payload bytes, which is what the Swift/CryptoKit side verifies.
func (s *Signer) Sign(claims Claims) (string, error) {
	if claims.V == 0 {
		claims.V = 1
	}
	if claims.KID == "" {
		claims.KID = s.kid
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("license: marshal claims: %w", err)
	}
	encoded := base64.RawURLEncoding.EncodeToString(payload)
	sig := ed25519.Sign(s.priv, []byte(encoded))
	return TokenPrefix + "." + encoded + "." + base64.RawURLEncoding.EncodeToString(sig), nil
}

// Verify checks the signature and returns the claims. It does not decide whether
// the license is currently usable; the caller checks product, status, expiry, and
// install id.
func Verify(token string, publicKey ed25519.PublicKey) (Claims, error) {
	var claims Claims
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return claims, errors.New("license: malformed token")
	}
	if parts[0] != TokenPrefix {
		return claims, fmt.Errorf("license: unsupported token prefix %q", parts[0])
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return claims, fmt.Errorf("license: decode payload: %w", err)
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return claims, fmt.Errorf("license: decode signature: %w", err)
	}
	if len(publicKey) != ed25519.PublicKeySize {
		return claims, errors.New("license: invalid public key")
	}
	if !ed25519.Verify(publicKey, []byte(parts[1]), sig) {
		return claims, errors.New("license: signature mismatch")
	}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return claims, fmt.Errorf("license: decode claims: %w", err)
	}
	if claims.V != 1 {
		return claims, fmt.Errorf("license: unsupported version %d", claims.V)
	}
	return claims, nil
}
