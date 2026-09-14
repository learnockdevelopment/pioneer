/// ─── elmasa App Configuration ─────────────────────────────────────────────────
/// Single source of truth for all app-wide constants.
/// To change the site URL, edit ONLY this file.
library app_config;

/// The hostname used for all API calls and web referrers (no scheme, no trailing slash).
const String kSiteHost = 'nebras-academy.learnock.com';

/// The full HTTPS URL of the site (with scheme, no trailing slash).
const String kSiteUrl = 'https://$kSiteHost';
