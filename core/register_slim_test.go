//go:build slim

package core

import (
	"slices"
	"testing"

	C "github.com/sagernet/sing-box/constant"
)

func TestSlimRegistryContainsSupportedProtocols(t *testing.T) {
	for _, typ := range []string{C.TypeMixed, C.TypeSOCKS, C.TypeHTTP, C.TypeShadowsocks, C.TypeVMess, C.TypeTrojan, C.TypeVLESS, C.TypeAnyTLS} {
		if !slices.Contains(InboundRegistry().OptionTypes(), typ) {
			t.Errorf("slim inbound registry is missing %q", typ)
		}
	}
	for _, typ := range []string{C.TypeDirect, C.TypeBlock, C.TypeSOCKS, C.TypeHTTP, C.TypeShadowsocks, C.TypeVMess, C.TypeTrojan, C.TypeVLESS, C.TypeAnyTLS} {
		if !slices.Contains(OutboundRegistry().OptionTypes(), typ) {
			t.Errorf("slim outbound registry is missing %q", typ)
		}
	}
	if got := EndpointRegistry().OptionTypes(); len(got) != 0 {
		t.Fatalf("slim endpoint registry must be empty, got %v", got)
	}
}
