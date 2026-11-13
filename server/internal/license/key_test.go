package license

import (
	"strings"
	"testing"
)

func TestGenerateFormat(t *testing.T) {
	key, err := Generate("MULL")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	parts := strings.Split(key, "-")
	if len(parts) != Groups+1 {
		t.Fatalf("expected %d groups, got %d: %s", Groups+1, len(parts), key)
	}
	if parts[0] != "MULL" {
		t.Fatalf("prefix = %q, want MULL", parts[0])
	}
	for _, group := range parts[1:] {
		if len(group) != GroupLen {
			t.Fatalf("group %q has length %d, want %d", group, len(group), GroupLen)
		}
		for _, r := range group {
			if !strings.ContainsRune(Alphabet, r) {
				t.Fatalf("group %q contains %q outside the alphabet", group, r)
			}
		}
	}
	if key == mustGenerate(t, "MULL") {
		t.Fatal("two generated keys are identical")
	}
}

func TestGenerateSanitizesPrefix(t *testing.T) {
	cases := map[string]string{
		"mull":    "MULL",
		"FAT-CAT": "FATC",
		"a0o1i":   "AXXX",
		"":        "XXXX",
	}
	for input, want := range cases {
		key, err := Generate(input)
		if err != nil {
			t.Fatalf("Generate(%q): %v", input, err)
		}
		if got := strings.Split(key, "-")[0]; got != want {
			t.Errorf("prefix(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeAndHash(t *testing.T) {
	canonical := "MULL-7KQ2M-ABCDE-FGHJK-MNPQR"
	variants := []string{
		canonical,
		"mull 7kq2m abcde fghjk mnpqr",
		"MULL7KQ2MABCDEFGHJKMNPQR",
		"  MULL-7kq2m-abcde-fghjk-mnpqr  ",
	}
	want := Hash(canonical)
	for _, variant := range variants {
		if got := Hash(variant); got != want {
			t.Errorf("Hash(%q) = %q, want %q", variant, got, want)
		}
	}
	if Hash(canonical) == Hash(canonical[:len(canonical)-1]+"X") {
		t.Fatal("different keys hash to the same value")
	}
}

func TestHint(t *testing.T) {
	if got := Hint("MULL-7KQ2M-ABCDE-FGHJK-MNPQR"); got != "MNPQR" {
		t.Fatalf("Hint = %q, want MNPQR", got)
	}
	if got := Hint("abc"); got != "ABC" {
		t.Fatalf("Hint(short) = %q, want ABC", got)
	}
}

func TestEncryptDecrypt(t *testing.T) {
	secret := []byte("test-secret")
	key, err := Generate("MULL")
	if err != nil {
		t.Fatal(err)
	}
	sealed, err := Encrypt(secret, key)
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if strings.Contains(sealed, key) {
		t.Fatal("ciphertext contains plaintext key")
	}
	opened, err := Decrypt(secret, sealed)
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if opened != key {
		t.Fatalf("round trip = %q, want %q", opened, key)
	}
	if _, err := Decrypt([]byte("wrong"), sealed); err == nil {
		t.Fatal("Decrypt with the wrong secret succeeded")
	}
	if _, err := Encrypt(nil, key); err == nil {
		t.Fatal("Encrypt with an empty secret succeeded")
	}
}

func TestKeyIsNotReversibleFromHash(t *testing.T) {
	key, err := Generate("MULL")
	if err != nil {
		t.Fatal(err)
	}
	hash := Hash(key)
	if len(hash) != 64 {
		t.Fatalf("hash length = %d, want 64", len(hash))
	}
	if strings.Contains(hash, Normalize(key)) {
		t.Fatal("hash contains the key")
	}
}

func mustGenerate(t *testing.T, prefix string) string {
	t.Helper()
	key, err := Generate(prefix)
	if err != nil {
		t.Fatal(err)
	}
	return key
}
