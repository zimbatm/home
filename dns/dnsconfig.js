// Declarative DNS for zimbatm.com, ztm.io, chevalier.sh.
//
// Reality source: Namecheap (registrar + DNS).
// Workflow:
//   nix run .#dns-preview    # diff between this file and Namecheap state
//   nix run .#dns-push       # apply the diff (idempotent)
//
// The creds.json is generated at runtime by the flake apps from the
// NAMECHEAP_API_USER and NAMECHEAP_API_KEY in .envrc.local — never commit it.

var REG_NC = NewRegistrar("namecheap");
var DNS_NC = NewDnsProvider("namecheap");

// ----------------------------------------------------------------------------
// zimbatm.com — work-ish/public identity. MX on Fastmail.
// ----------------------------------------------------------------------------

// Host targets.
var WEB2_A    = "89.167.46.118";
var WEB2_AAAA = "2a01:4f9:c014:fac3::1";
var MAIL_A    = "89.167.29.31";
var MAIL_AAAA = "2a01:4f9:c015:5dc::1";
var CHAT_A    = "178.105.105.181";
var CHAT_AAAA = "2a01:4f8:c014:94be::1";
var AGENTS_A    = "178.105.193.91";
var AGENTS_AAAA = "2a01:4f8:c014:7e84::1";
var MC1_A       = "178.105.205.187";
var MC1_AAAA    = "2a01:4f8:c013:cb17::1";

D("zimbatm.com", REG_NC, DnsProvider(DNS_NC),
  DefaultTTL(1800),

  // ─── A/AAAA ───
  A("@",       WEB2_A),
  AAAA("@",    WEB2_AAAA),
  A("gts",     WEB2_A),
  AAAA("gts",  WEB2_AAAA),
  // Pocket ID — SSO root for agents.ztm.io. Lives on web2 since #82.
  A("id",    WEB2_A),
  AAAA("id", WEB2_AAAA),
  // Self-hosted AT Protocol PDS (handle @zimbatm.com → the _atproto TXT
  // DID below). Lives on web2.
  A("pds",    WEB2_A),
  AAAA("pds", WEB2_AAAA),

  // ─── CNAME ───
  CNAME("www",             "zimbatm.com."),
  CNAME("sl",              "sl.m2-use1.sendlayer.net.", TTL(300)),         // Sendlayer transactional
  CNAME("track.sl",        "track.m2.sendlayer.net.",   TTL(300)),
  CNAME("sl._domainkey",   "sl._domainkey.m2.sendlayer.net.", TTL(300)),
  CNAME("_dmarc.sl",       "_dmarc.m2.sendlayer.net.",  TTL(300)),

  // ─── MX (Fastmail) ───
  MX("@", 10, "in1-smtp.messagingengine.com."),
  MX("@", 20, "in2-smtp.messagingengine.com."),
  MX("*", 10, "in1-smtp.messagingengine.com."),
  MX("*", 20, "in2-smtp.messagingengine.com."),

  // ─── Fastmail DKIM (CNAMEs, rotated by Fastmail) ───
  CNAME("fm1._domainkey", "fm1.zimbatm.com.dkim.fmhosted.com."),
  CNAME("fm2._domainkey", "fm2.zimbatm.com.dkim.fmhosted.com."),
  CNAME("fm3._domainkey", "fm3.zimbatm.com.dkim.fmhosted.com."),

  // ─── TXT ───
  TXT("@",        "v=spf1 include:spf.messagingengine.com ?all"),
  TXT("@",        "google-site-verification=mRPDMyxbG7TJi2SMfaT0uVqSEfo2DR3ukqJwR_t6L9w"),
  TXT("_atproto", "did=did:plc:wxnofyouho6vcuevbvocutid"),
  TXT("_dmarc",   "v=DMARC1; p=none; rua=mailto:dmarc@zimbatm.com; ruf=mailto:dmarc@zimbatm.com; fo=1; aspf=r; adkim=r"),

  // Sendlayer return-path TXT
  TXT("e3bhjstxcz.sl", "wzxjxsyzmdb3ek4fcxpphjb3mzhezdrp7h3w4wrkzsfaaehd7ytfcwdprmxk", TTL(300)),

  // Legacy DKIM (RSA) kept around in case old archived mail needs to
  // re-verify; harmless even if no longer used for new outbound.
  TXT("cf2024-1._domainkey",     "v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiweykoi+o48IOGuP7GR3X0MOExCUDY/BCRHoWBnh3rChl7WhdyCxW3jgq1daEjPPqoi7sJvdg5hEQVsgVRQP4DcnQDVjGMbASQtrY4WmB1VebF+RPJB2ECPsEDTpeiI5ZyUAwJaVX7r6bznU67g7LvFq35yIo4sdlmtZGV+i0H4cpYH9+3JJ78km4KXwaf9xUJCWF6nxeD+qG6Fyruw1Qlbds2r85U9dkNDVAS3gioCvELryh1TxKGiVTkg4wqHTyHfWsp7KD3WQHYJn0RyfJJu6YEmL77zonn7p2SRMvTMP3ZEXibnC9gz3nnhR6wcYL8Q7zXypKTMD58bTixDSJwIDAQAB"),
  TXT("google._domainkey",       "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCZr2QuB5lY0+W0kF9v6EJw0P8yW25PsOaZMkRBg52Z2e3u3nAZlqRM74y48ieohUv/PbXVyg9iaHNFMo39uBi1b6vgJVkHL19cdK/u84S01bgVSMCDQcmGbFE+dfDMPDie5y6cBVds1HFLFBsTLI7PmX+FweT7+UM767XQ3lvqOQIDAQAB"),
);

// ----------------------------------------------------------------------------
// ztm.io — internal services (chat box weechat relay, mail webmail).
// ----------------------------------------------------------------------------

D("ztm.io", REG_NC, DnsProvider(DNS_NC),
  DefaultTTL(1800),

  A("chat",      CHAT_A),
  AAAA("chat",   CHAT_AAAA),
  A("mail",      MAIL_A),
  AAAA("mail",   MAIL_AAAA),
  A("agents",    AGENTS_A),
  AAAA("agents", AGENTS_AAAA),
  // pi-web PWA (spaces remote-agent / pi-sessiond), same host as the terminal.
  A("agent",     AGENTS_A),
  AAAA("agent",  AGENTS_AAAA),
  A("mc",        MC1_A),
  AAAA("mc",     MC1_AAAA),
);

// ----------------------------------------------------------------------------
// chevalier.sh — personal identity. MX on Fastmail.
// ----------------------------------------------------------------------------

D("chevalier.sh", REG_NC, DnsProvider(DNS_NC),
  DefaultTTL(1800),

  // cal.chevalier.sh — partner-visible calendar publisher (task #62, deferred)
  A("cal",    WEB2_A),
  AAAA("cal", WEB2_AAAA),

  // ─── MX (Fastmail) ───
  MX("@", 10, "in1-smtp.messagingengine.com."),
  MX("@", 20, "in2-smtp.messagingengine.com."),
  MX("*", 10, "in1-smtp.messagingengine.com."),
  MX("*", 20, "in2-smtp.messagingengine.com."),

  // ─── Fastmail DKIM (CNAMEs, rotated by Fastmail) ───
  CNAME("fm1._domainkey", "fm1.chevalier.sh.dkim.fmhosted.com."),
  CNAME("fm2._domainkey", "fm2.chevalier.sh.dkim.fmhosted.com."),
  CNAME("fm3._domainkey", "fm3.chevalier.sh.dkim.fmhosted.com."),

  // SPF — allow Fastmail outbound.
  TXT("@",      "v=spf1 include:spf.messagingengine.com ?all"),
  TXT("_dmarc", "v=DMARC1; p=none; rua=mailto:dmarc@chevalier.sh; ruf=mailto:dmarc@chevalier.sh; fo=1; aspf=r; adkim=r"),
);
