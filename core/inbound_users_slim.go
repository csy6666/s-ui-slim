//go:build slim

package core

import (
	suiAnytls "github.com/alireza0/s-ui/core/protocol/anytls"
	suiShadowsocks "github.com/alireza0/s-ui/core/protocol/shadowsocks"
	suiTrojan "github.com/alireza0/s-ui/core/protocol/trojan"
	suiVless "github.com/alireza0/s-ui/core/protocol/vless"
	suiVmess "github.com/alireza0/s-ui/core/protocol/vmess"

	"github.com/alireza0/s-ui/core/usersession"
	"github.com/sagernet/sing-box/option"
	sbCommon "github.com/sagernet/sing/common"
)

// UpdateInboundUsers only contains protocols registered by the slim build.
func (c *Core) UpdateInboundUsers(config []byte) (bool, error) {
	box, err := c.running()
	if err != nil {
		return false, err
	}
	var inboundConfig option.Inbound
	if err = inboundConfig.UnmarshalJSONContext(box.ctx, config); err != nil {
		return false, err
	}
	inb, found := box.inbound.Get(inboundConfig.Tag)
	if !found {
		return false, nil
	}
	switch options := inboundConfig.Options.(type) {
	case *option.VLESSInboundOptions:
		if in, ok := inb.(*suiVless.Inbound); ok {
			return true, in.UpdateUsers(options.Users)
		}
	case *option.VMessInboundOptions:
		if in, ok := inb.(*suiVmess.Inbound); ok {
			return true, in.UpdateUsers(options.Users)
		}
	case *option.TrojanInboundOptions:
		if in, ok := inb.(*suiTrojan.Inbound); ok {
			return true, in.UpdateUsers(options.Users)
		}
	case *option.AnyTLSInboundOptions:
		if in, ok := inb.(*suiAnytls.Inbound); ok {
			return true, in.UpdateUsers(options.Users)
		}
	case *option.ShadowsocksInboundOptions:
		if options.Managed || len(options.Users) == 0 {
			return false, nil
		}
		if in, ok := inb.(*suiShadowsocks.MultiInbound); ok {
			return true, in.UpdateUsers(sbCommon.Map(options.Users, func(it option.ShadowsocksUser) string {
				return it.Name
			}), sbCommon.Map(options.Users, func(it option.ShadowsocksUser) string {
				return it.Password
			}))
		}
	}
	return false, nil
}

func (c *Core) CloseInboundUserSessions(tag string, keep map[string]struct{}) int {
	box, err := c.running()
	if err != nil {
		return 0
	}
	inb, found := box.inbound.Get(tag)
	if !found {
		return 0
	}
	closer, ok := inb.(usersession.Closer)
	if !ok {
		return 0
	}
	return closer.CloseUserSessions(keep)
}

func (c *Core) KickUserSessions(user string) int {
	box, err := c.running()
	if err != nil {
		return 0
	}
	kicked := 0
	for _, inb := range box.inbound.Inbounds() {
		if closer, ok := inb.(usersession.Closer); ok {
			kicked += closer.KickUserSessions(user)
		}
	}
	return kicked
}
