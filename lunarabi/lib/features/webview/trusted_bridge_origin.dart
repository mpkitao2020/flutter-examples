bool isTrustedBridgeOrigin(Uri? committed, Uri webBaseUrl) {
  if (committed == null) return false;
  if (committed.scheme != webBaseUrl.scheme) return false;
  if (committed.host != webBaseUrl.host) return false;
  // Uri.port is the effective port, including 80 / 443 when omitted.
  return committed.port == webBaseUrl.port;
}
