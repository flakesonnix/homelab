// Command homectl-api is the homectl control-plane server (M0: health + meta).
package main

import (
	"flag"
	"log"
	"net/http"
	"os"

	"homectl/api/http"
	"homectl/shared/version"
)

func main() {
	addr := flag.String("addr", ":8443", "listen address")
	manifestPath := flag.String("manifest", "manifest.json", "path to Nix-generated manifest.json")
	uiPath := flag.String("ui", "ui.json", "path to Nix-generated ui.json")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		log.Println(version.String())
		return
	}

	manifest, err := os.ReadFile(*manifestPath)
	if err != nil {
		log.Fatalf("read manifest: %v", err)
	}
	ui, err := os.ReadFile(*uiPath)
	if err != nil {
		log.Fatalf("read ui: %v", err)
	}

	server, err := httpapi.New(manifest, ui)
	if err != nil {
		log.Fatalf("init server: %v", err)
	}

	log.Printf("%s listening on %s", version.String(), *addr)
	if err := http.ListenAndServe(*addr, server.Handler()); err != nil {
		log.Fatal(err)
	}
}
