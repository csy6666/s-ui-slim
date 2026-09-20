package config

import (
	"os"
	"runtime/debug"
)

// ConfigureRuntime sets a Go-managed memory target, not a process RSS cap.
// Explicit operator settings take precedence. CGO, sockets and the kernel
// still require headroom outside this budget.
func ConfigureRuntime() {
	if !IsSlimBuild() {
		return
	}
	if os.Getenv("GOMEMLIMIT") == "" {
		debug.SetMemoryLimit(64 << 20)
	}
	if os.Getenv("GOGC") == "" {
		debug.SetGCPercent(50)
	}
}
