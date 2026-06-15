# 0Cert Browser — iOS

> A browser that actually trusts you.

0Cert Browser is a native Swift iOS app that browses the web with 
**Identity-Based Cryptography** — no certificates, no renewals, 
identity-bound encryption built in.

---

## What makes it different

Normal browsers trust ~150 Certificate Authorities.  
Any one of them can be hacked and issue fake certificates for any site.

0Cert Browser adds a second layer — **IBC verification**:

Normal browser:

visits site → checks SSL cert → green padlock → done

Problem: 150 CAs can fake any certificate
0Cert Browser:

visits site → checks SSL cert (still works)

→ checks DNS for ibc-kgc record

→ if found: establishes IBC encrypted channel

→ shows IBC Verified badge

→ identity-bound encryption active

→ even a compromised CA can't fake this

---

## Features

- **Full browser** — WKWebView, works on all websites
- **IBC verification** — detects 0Cert-enabled sites via DNS TXT records
- **Three trust levels** — IBC Verified / Standard SSL / Checking
- **Identity management** — your email is your cryptographic identity
- **Key vault** — keys stored in iOS Keychain, never leave your device
- **Site registration** — website owners can register their domain in one tap
- **Zero config** — onboards in 30 seconds

---

## How it works

### For users

Download 0Cert Browser
Enter your email → keys generated on device
Browse normally
IBC-enabled sites show green "IBC Verified" badge

### For website owners

Open My Sites tab → tap +
Enter your domain
App generates your keys and shows:

→ DNS TXT record to add

→ npm middleware to install
Your site shows verified badge to all 0Cert users

---

## Architecture
IBCBrowserApp.swift       — app entry point

ContentView.swift         — tab controller

BrowserView.swift         — WKWebView + address bar + IBC status

IBCEngine.swift           — DNS lookup, KGC verification, trust status

KeyVaultManager.swift     — iOS Keychain key storage (CryptoKit P-256)

OnboardingView.swift      — 3-step identity setup

DashboardView.swift       — key management + verified sites

SiteRegistrationView.swift — register your domain with 0Cert

---

## Cryptography

Keys are generated using **CryptoKit P-256 ECDH** — Apple's own 
hardware-backed crypto library. Private keys never leave the device.

userSecret           = P-256 private key (generated on device)

userPublicCommitment = P-256 public key (safe to publish)

partialKey           = issued by KGC for your identity

fullPrivKey          = combine(partialKey, userSecret)

→ KGC never knows this key

→ only you can decrypt

---

## Requirements
iOS 17+

Xcode 15+

Swift 5.9+

---

## Build & Run

```bash
git clone https://github.com/0cert/ios-browser
cd ios-browser
open IBCBrowser.xcodeproj
```

Hit **Cmd+R** to run in simulator.

The app connects to the public KGC at **https://kgc.0cert.io** by default.  
Enterprise users can point to their own private KGC in Advanced Settings.

---

## KGC Server

The Key Generation Center that powers this app:  
→ [github.com/0cert/kgc-server](https://github.com/0cert/kgc-server)

Live public KGC: **https://kgc.0cert.io**

---

## The bigger picture

Today     → iOS browser + public KGC

Next      → npm middleware for websites

Then      → DNS-based trust, no extension needed

Future    → IETF RFC + native browser support

Endgame   → Your identity IS the certificate.

The web. Zero certificates.

---

## License

MIT — build something with it.

---

*Part of the [0Cert](https://github.com/0cert) project —   
replacing SSL certificates with identity-based cryptography.*

