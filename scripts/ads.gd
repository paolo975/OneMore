extends Node

# Ads through the Poing AdMob plugin. Where neither the native singleton nor the mock the plugin
# ships for editor builds exists — the exported Windows build, a phone without the plugin — every
# call is a no-op: the game never waits on an ad. The GMA Next-Gen SDK initialises asynchronously
# and throws if asked to load before it has finished, so every load waits for its callback.
# Unit ids come from res://ads.cfg; the App ID lives in project.godot under [admob].

const BANNER_RESERVE = 90.0

var enabled = false
var initialized = false
var banner_wanted = false
var banner_loaded = false
var config = {"test": true}
var _ids = {}
var _banner = null
var _interstitial = null
var _loading = false
var _shown = null

func _ready() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("res://ads.cfg") == OK:
		config["test"] = bool(cfg.get_value("ads", "test", true))
		var section = "test" if config["test"] else "production"
		_ids = {
			"banner": str(cfg.get_value(section, "banner", "")),
			"interstitial": str(cfg.get_value(section, "interstitial", "")),
		}
	else:
		# Loud, not silent: a config left out of the export is exactly what switched the ads off once.
		print("AdMob: ads.cfg non trovato, pubblicità spenta")
	enabled = has_plugin() and unit("banner") != ""
	if not enabled:
		return
	# The audience is children: child-directed treatment, G-rated, hence non-personalised.
	var rules = RequestConfiguration.new()
	rules.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	rules.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(rules)
	var listener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialized
	MobileAds.initialize(listener)

# The native plugin on a phone, or the mock the plugin provides in editor builds.
func has_plugin() -> bool:
	return Engine.has_singleton("PoingGodotAdMob") or OS.has_feature("editor")

func _on_initialized(_status) -> void:
	initialized = true
	print("AdMob: inizializzato")
	preload_interstitial()
	if banner_wanted:
		show_banner()

func unit(kind: String) -> String:
	return str(_ids.get(kind, ""))

# Height, in canvas units, to keep clear at the bottom for the anchored banner.
func banner_reserve() -> float:
	return BANNER_RESERVE if enabled else 0.0

func show_banner() -> void:
	if not enabled:
		return
	banner_wanted = true
	if not initialized:
		return
	if _banner == null:
		var size = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(unit("banner"), size, AdPosition.BOTTOM)
		var listener = AdListener.new()
		listener.on_ad_loaded = func() -> void:
			banner_loaded = true
			print("AdMob: banner caricato")
		listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
			# The plugin may hand over null, and the view may already be gone: guard both, or the
			# lambda aborts before dropping the view and the next game never retries.
			if error != null:
				print("AdMob: banner fallito codice %d: %s" % [error.code, error.message])
			else:
				print("AdMob: banner fallito")
			if _banner != null:
				_banner.destroy()
				_banner = null
			banner_loaded = false
		_banner.ad_listener = listener
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()

func hide_banner() -> void:
	if _banner != null:
		_banner.hide()

func preload_interstitial() -> void:
	if not enabled or not initialized or _interstitial != null or _loading:
		return
	_loading = true
	var callback = InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		_loading = false
		print("AdMob: interstitial caricato")
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading = false
		print("AdMob: interstitial fallito codice %d: %s" % [error.code, error.message])
	InterstitialAdLoader.new().load(unit("interstitial"), AdRequest.new(), callback)

# Returns true only if an ad actually went on screen; the caller never blocks on it.
func show_interstitial() -> bool:
	if not enabled or _interstitial == null:
		preload_interstitial()
		return false
	_shown = _interstitial
	_interstitial = null
	# Bound methods, not lambdas capturing the ad: a lambda stored inside the ad that
	# captures the ad is a reference cycle nothing would ever break.
	_shown.full_screen_content_callback.on_ad_dismissed_full_screen_content = _after_interstitial
	_shown.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = _after_interstitial_error
	print("AdMob: interstitial mostrato")
	_shown.show()
	return true

func _after_interstitial() -> void:
	if _shown != null:
		_shown.destroy()
		_shown = null
	preload_interstitial()

func _after_interstitial_error(_error: AdError) -> void:
	_after_interstitial()

func _exit_tree() -> void:
	if _banner != null:
		_banner.destroy()
		_banner = null
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	if _shown != null:
		_shown.full_screen_content_callback = FullScreenContentCallback.new()
		_shown.destroy()
		_shown = null
