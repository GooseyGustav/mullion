package license

import (
	"crypto/ed25519"
	"crypto/rand"
	"os"
	"path/filepath"
	"testing"
)

func testClaims() Claims {
	expires := "2027-01-01T00:00:00Z"
	return Claims{
		LicenseID: "lic_test",
		Product:   "mullion",
		Plan:      "pro",
		Status:    "active",
		Seats:     3,
		Major:     1,
		IssuedAt:  "2026-11-13T12:00:00Z",
		ExpiresAt: &expires,
		InstallID: "0123456789abcdef",
		KeyHint:   "MNPQR",
	}
}

func TestSignerRoundTrip(t *testing.T) {
	signer, err := NewSigner("2026-11")
	if err != nil {
		t.Fatalf("NewSigner: %v", err)
	}
	token, err := signer.Sign(testClaims())
	if err != nil {
		t.Fatalf("Sign: %v", err)
	}
	if token[:5] != "LIC1." {
		t.Fatalf("token prefix = %q, want LIC1.", token[:5])
	}
	claims, err := Verify(token, signer.PublicKey())
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if claims.LicenseID != "lic_test" || claims.Product != "mullion" {
		t.Fatalf("claims = %+v", claims)
	}
	if claims.V != 1 || claims.KID != "2026-11" {
		t.Fatalf("version/kid = %d/%q", claims.V, claims.KID)
	}
	if claims.ExpiresAt == nil || *claims.ExpiresAt != "2027-01-01T00:00:00Z" {
		t.Fatalf("expires_at = %v", claims.ExpiresAt)
	}
}

func TestVerifyRejectsTampering(t *testing.T) {
	signer, err := NewSigner("2026-11")
	if err != nil {
		t.Fatal(err)
	}
	token, err := signer.Sign(testClaims())
	if err != nil {
		t.Fatal(err)
	}

	// Flip a character in the payload segment.
	tampered := []byte(token)
	for i := 6; i < len(tampered); i++ {
		if tampered[i] == 'A' {
			tampered[i] = 'B'
			break
		}
	}
	if _, err := Verify(string(tampered), signer.PublicKey()); err == nil {
		t.Fatal("Verify accepted a tampered payload")
	}

	other, err := NewSigner("2026-11")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Verify(token, other.PublicKey()); err == nil {
		t.Fatal("Verify accepted a token from another key")
	}
}

func TestVerifyRejectsMalformed(t *testing.T) {
	pub, _, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	for _, token := range []string{
		"",
		"LIC1",
		"LIC1.a",
		"LIC2.abc.def",
		"LIC1.!!!.!!!",
	} {
		if _, err := Verify(token, pub); err == nil {
			t.Errorf("Verify(%q) succeeded", token)
		}
	}
}

func TestSignerSaveLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "signing-key.pem")

	signer, err := NewSigner("2026-11")
	if err != nil {
		t.Fatal(err)
	}
	if err := signer.Save(path); err != nil {
		t.Fatalf("Save: %v", err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %o, want 600", info.Mode().Perm())
	}

	loaded, err := LoadSigner(path, "2026-11")
	if err != nil {
		t.Fatalf("LoadSigner: %v", err)
	}
	if loaded.PublicKeyBase64URL() != signer.PublicKeyBase64URL() {
		t.Fatal("loaded key differs from the original")
	}
	token, err := loaded.Sign(testClaims())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Verify(token, signer.PublicKey()); err != nil {
		t.Fatalf("token from loaded key does not verify: %v", err)
	}
}

func TestParseSignerRawSeed(t *testing.T) {
	signer, err := NewSigner("2026-11")
	if err != nil {
		t.Fatal(err)
	}
	// Save writes PKCS#8; parse it directly to exercise the PEM path.
	dir := t.TempDir()
	path := filepath.Join(dir, "key.pem")
	if err := signer.Save(path); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := ParseSigner(data, "2026-11")
	if err != nil {
		t.Fatalf("ParseSigner: %v", err)
	}
	if parsed.PublicKeyBase64URL() != signer.PublicKeyBase64URL() {
		t.Fatal("parsed key differs")
	}
}
