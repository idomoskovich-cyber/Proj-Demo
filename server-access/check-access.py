#!/usr/bin/env python3
"""Check HTTPS reachability without credentials or disabled TLS verification."""
import argparse
from html.parser import HTMLParser
import ssl
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import build_opener, HTTPSHandler, HTTPRedirectHandler, Request


class HTTPSOnlyRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        target = urlsplit(newurl)
        if target.scheme != "https" or target.username or target.password:
            raise URLError("Refused a redirect without verified HTTPS or with embedded credentials")
        return super().redirect_request(request, fp, code, msg, headers, newurl)


class PageTitle(HTMLParser):
    def __init__(self):
        super().__init__()
        self.inside = False
        self.finished = False
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == "title" and not self.finished:
            self.inside = True

    def handle_endtag(self, tag):
        if tag == "title" and self.inside:
            self.inside = False
            self.finished = True

    def handle_data(self, data):
        if self.inside:
            self.parts.append(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", nargs="?", default="https://192.168.1.223:8006/")
    parser.add_argument("--ca-file", help="Verified public PEM CA certificate, if needed")
    args = parser.parse_args()
    url = urlsplit(args.url)
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.query:
        parser.error("Use an HTTPS URL without embedded credentials or a query string")
    context = ssl.create_default_context()
    if args.ca_file:
        context.load_verify_locations(cafile=args.ca_file)
    # The default opener uses inherited proxy variables and NO_PROXY settings.
    opener = build_opener(HTTPSHandler(context=context), HTTPSOnlyRedirects())
    try:
        with opener.open(Request(args.url, headers={"User-Agent": "ServerAccessReadiness/1.0"}), timeout=20) as response:
            html = response.read(1024 * 1024).decode("utf-8", errors="replace")
            title = PageTitle()
            title.feed(html)
            print("Verified HTTPS response:", response.status)
            print("Page title:", " ".join("".join(title.parts).split())[:200] or "(none)")
            print("Transport and page retrieval checked. Login and server management remain unverified.")
            return 0
    except HTTPError as error:
        print("HTTPS endpoint returned HTTP", error.code, file=sys.stderr)
        print("Application access is not verified.", file=sys.stderr)
        return 1
    except (URLError, TimeoutError, OSError) as error:
        reason = error.reason if isinstance(error, URLError) else error
        print("Access check failed:", reason, file=sys.stderr)
        print("Check VPN enrollment, destination permissions, routing, and TLS trust.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
