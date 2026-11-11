/// Public client configuration. The publishable key is safe to ship in the app;
/// row-level security on the database is what protects the data.
/// Point these at the production project before release.
abstract final class EnishConfig {
  static const supabaseUrl = 'https://gogjjqeykskyrotssnsr.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_caFdGFgLomAjsObnnkAs2A_HmMYx2YG';
}
