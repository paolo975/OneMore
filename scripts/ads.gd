extends Node

# Ads through the Poing AdMob plugin. Where the native singleton is missing — tests,
# Windows, the editor — every call is a no-op: the game never waits on an ad.
# Unit ids come from res://ads.cfg; the App ID lives in project.godot under [admob].

const BANNER_RESERVE = 90.0

var enabled = false
var config = {"test": true}
var _ids = {}
var _banner = null
var _interstitial = null
var _loading = false

func _ready() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("res://ads.cfg") == OK:
		config["test"] = bool(cfg.get_value("ads", "test", true))
		var section = "test" if config["test"] else "production"
		_ids = {
			"banner": str(cfg.get_value(section, "banner", "")),
			"interstitial": str(cfg.get_value(section, "interstitial", "")),
		}
	enabled = Engine.has_singleton("PoingGodotAdMob") and unit("banner") != ""
	if not enabled:
		return
	# The audience is children: child-directed treatment, G-rated, hence non-personalised.
	var rules = RequestConfiguration.new()
	rules.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	rules.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(rules)
	MobileAds.initialize()

func unit(kind: String) -> String:
	return str(_ids.get(kind, ""))

# Height, in canvas units, to keep clear at the bottom for the anchored banner.
func banner_reserve() -> float:
	return BANNER_RESERVE if enabled else 0.0

func show_banner() -> void:
	if not enabled:
		return
	if _banner == null:
		var size = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(unit("banner"), size, AdPosition.BOTTOM)
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()

func hide_banner() -> void:
	if _banner != null:
		_banner.hide()

func preload_interstitial() -> void:
	if not enabled or _interstitial != null or _loading:
		return
	_loading = true
	var callback = InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		_loading = false
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading = false
	InterstitialAdLoader.new().load(unit("interstitial"), AdRequest.new(), callback)

# Returns true only if an ad actually went on screen; the caller never blocks on it.
func show_interstitial() -> bool:
	if not enabled or _interstitial == null:
		preload_interstitial()
		return false
	var ad = _interstitial
	_interstitial = null
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		preload_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		preload_interstitial()
	ad.show()
	return true
