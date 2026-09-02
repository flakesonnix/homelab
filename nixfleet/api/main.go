// Command nixfleet-api is the nixfleet control-plane server (M0: health + meta).
package main

import (
	"flag"
	"log"
	"net/http"
	"os"

	"nixfleet/api/http"
	"nixfleet/shared/version"
)

func main() {
	addr := flag.String("addr", ":8443", "listen address")
	manifestPath := flag.String("manifest", "manifest.json", "path to Nix-generated manifest.json")
	uiPath := flag.String("ui", "ui.json", "path to Nix-generated ui.json")
	webDir := flag.String("web", "", "optional path to the built frontend to serve at /")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		log.Println(version.String())
		return
	}

	manifest, err := os.ReadFile(*manifestPath)
	if err != nil {
		log.Fatalf("nixfleet-api: failed to read manifest %q: %v (check lucy.nixfleet.api.artifactsDir, file must contain valid manifest.json from nixfleet/manifest.nix)", *manifestPath, err)
	}
	ui, err := os.ReadFile(*uiPath)
	if err != nil {
		log.Fatalf("nixfleet-api: failed to read ui %q: %v (check lucy.nixfleet.api.artifactsDir, file must contain valid ui.json)", *uiPath, err)
	}

	server, err := httpapi.New(manifest, ui)
	if err != nil {
		log.Fatalf("nixfleet-api: failed to parse manifest/ui %q/%q: %v (check JSON validity, run `nix build .#nixfleet-manifest`)", *manifestPath, *uiPath, err)
	}
	if *webDir != "" {
		server.ServeWeb(*webDir)
		log.Printf("serving frontend from %s", *webDir)
	}

	log.Printf("%s listening on %s (manifest %s, ui %s)", version.String(), *addr, *manifestPath, *uiPath)
	if err := http.ListenAndServe(*addr, server.Handler()); err != nil {
		log.Fatalf("nixfleet-api: http server failed on %s: %v", *addr, err)
	}
}
