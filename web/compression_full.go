//go:build !slim

package web

import (
	"github.com/gin-contrib/gzip"
	"github.com/gin-gonic/gin"
)

func useCompression(engine *gin.Engine) {
	engine.Use(gzip.Gzip(gzip.DefaultCompression))
}
