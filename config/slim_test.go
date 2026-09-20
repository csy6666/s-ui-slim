//go:build slim

package config

import "testing"

func TestSlimBuild(t *testing.T) {
	if !IsSlimBuild() {
		t.Fatal("slim build flag was not active")
	}
}
