# Security policy

WebImagePicker loads **user-supplied URLs** in the client (HTML pages and discovered image URLs). This document describes what that implies and how to report problems.

## Threat model (client apps)

- **End-user driven fetches:** The library is designed for flows where the person using the app chooses or enters a URL. Risk is primarily **untrusted web content** (malicious pages, large responses, unexpected redirects) and **whatever the app does with downloaded bytes**, not classic server-side SSRF against your infrastructure.
- **If you proxy URLs through your backend:** Treat URL handling as **server-side**. Validate schemes and hosts, apply allowlists or denylists, and mitigate **SSRF** (e.g. blocking private/link-local ranges, metadata endpoints, and internal hostnames) according to your environment. This package does not implement server-side URL policy.

## What we do not guarantee

- **TLS:** Certificate validation follows the **system** URL loading stack (e.g. `URLSession` / WebKit); the library does not replace or weaken platform defaults.
- **Content safety:** Fetched HTML and images are **opaque data**. The library does not scan for malware, illegal content, or policy violations. Apps are responsible for storage, display, and further processing.
- **Availability or abuse:** No built-in rate limiting or bot protection; hosts may block or throttle clients.

## Supported versions

Security fixes are applied to the **latest tagged release** and, when practical, backported to the previous minor line. Use a [released version](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/tags) rather than an arbitrary commit when integrating.

## Reporting a vulnerability

Please **do not** open a public issue for undisclosed security problems.

**Preferred:** Use [GitHub private vulnerability reporting](https://github.com/fennelouski/SwiftUI-Web-Image-Picker/security/advisories/new) for this repository (if enabled for the project).

**Alternative:** Email the maintainer with a clear subject line (e.g. “Security: WebImagePicker”) and enough detail to reproduce or assess impact. Allow a reasonable window for a fix before public disclosure.

We aim to acknowledge reports promptly and coordinate disclosure after a fix is available.

## Security-related contributions

Improvements that harden default behavior without breaking legitimate use cases (e.g. safer URL handling, clearer documentation) are welcome. Large behavior changes may be discussed in an issue or advisory first.
