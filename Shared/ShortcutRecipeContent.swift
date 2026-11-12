import Foundation

/// Full Shortcuts “source” for PoopLock Wi‑Fi — also shown in Settings → View shortcut recipe.
enum ShortcutRecipeContent {
    /// Human-readable steps (in-app + copy).
    static let fullInstructions: String = """
    POOPLOCK WI‑FI SHORTCUT — BUILD IN THE SHORTCUTS APP
    ==================================================

    START — YOU DON’T HAVE A .shortcut FILE YET? THAT’S NORMAL
    ------------------------------------------------------------
    This document is not a download link. It is the step‑by‑step to CREATE the shortcut inside
    Apple’s Shortcuts app. When you finish, a real shortcut appears in My Shortcuts — then PoopLock
    can run it. PoopLock cannot inject a shortcut into Shortcuts for you (Apple does not allow it).
    To ship a file for others: build once → Shortcuts ••• → Share → export — see Shortcuts/EXPORT-INSTRUCTIONS.txt.


    FASTEST PATH — 3 ACTIONS (dbm ONLY, ENOUGH FOR POOPLOCK)
    --------------------------------------------------------
    If the long URL in “ACTIONS” feels hard, build this minimal version first:

    1) Shortcuts → + → Add Action → “Get Network Details” → Network: Wi‑Fi.

    2) Add Action → “Text”. Type:  pooplock://wifi?dbm=
       After the = sign, use “Insert Variable” / magic variable and pick RSSI from the previous step
       (iOS may label it “RSSI” or under “Network Details”).

    3) Add Action → “Open URLs” (or “Open URL”) → input = the Text from step 2.

    4) ••• → Rename → \(PoopLockWifiShortcut.defaultName)

    5) Tap ▶︎ Run. PoopLock should open briefly. Then use PoopLock → Test: run Wi‑Fi shortcut.

    Add ssid, bssid, Mbps, etc. later using the full Text line in ACTIONS below if you want.


    NAME (REQUIRED — MUST MATCH POOPLOCK SETTINGS EXACTLY)
    ------------------------------------------------------
    After you create the shortcut, tap ••• → Rename and set:

        \(PoopLockWifiShortcut.defaultName)

    Same spelling, spacing, and CAPITALIZATION as in PoopLock → Settings → “Exact name in Shortcuts app”.
    Example: PoopLockWIFI and PoopLockWiFi are different — Shortcuts must match letter-for-letter.
    If the name does not match, iOS shows: “Could not find the shortcut” (or that the shortcut/file does not exist).

    APP INTENT (ALTERNATIVE — NO URL RECIPE REQUIRED FOR A QUICK TEST)
    ------------------------------------------------------------------
    With PoopLock installed, open Shortcuts → Add Action → search “PoopLock” → “Get PoopLock Wi‑Fi snapshot”.
    That runs in-app code (NEHotspotNetwork) and returns SSID, BSSID, and signal. Different from the
    pooplock://wifi URL flow above, but same WiFiman-style idea (custom Shortcuts action).


    ACTIONS (IN ORDER)
    ------------------
    1) Add Action → search: “Get Network Details”
       - Network: Wi‑Fi

    2) Add Action → “Text”
       Build ONE line URL using variables from Get Network Details (tap to insert):

       pooplock://wifi?dbm=RSSI&ssid=NETWORK_NAME&bssid=BSSID&rxMbps=RX_RATE&txMbps=TX_RATE&noise=NOISE&channel=CHANNEL_NUMBER&standard=WIFI_STANDARD

       Replace each token with the matching magic variable from “Get Network Details”
       (RSSI, Network Name, BSSID, RX Rate, TX Rate, Noise, Channel Number, Wi‑Fi Standard).

       Minimum required for PoopLock: dbm (RSSI), e.g. dbm=-58

       If SSID or standard has spaces, URL-encode those parts or use Shortcuts’ “URL Encode”.

    3) Add Action → “Open URLs” (or “Open URL”)
       - Input: the Text from step 2.


    TEST
    ----
    Run the shortcut from Shortcuts. PoopLock should open briefly and Settings should show
    “Last Wi‑Fi payload”.


    OPTIONAL FIELDS (PoopLock parses these query names)
    ----------------------------------------------------
    dbm, rssi, ssid, bssid, rxMbps, txMbps, noise, channel, standard
    (Aliases in code: ShortcutWiFiReading / PoopLockURLHandler.parseWiFiImport)


    YOUR OWN ICLOUD SHARE LINK (NOT WIFIMAN’S)
    ------------------------------------------
    WiFiman’s icloud.com/shortcuts/… links install their shortcut for their app — not pooplock://wifi.
    Old links often show “Not Found” if removed or unpublished. After you build this recipe, use
    Shortcuts → ••• → Share → Copy Link and paste it into PoopLock Settings → “iCloud shortcut link”.


    WHY NOT IN APP CODE?
    --------------------
    Apple does not let App Store apps read live Wi‑Fi RSSI / PHY Mbps directly.
    Shortcuts “Get Network Details” can — so we pass data back via pooplock://wifi?...
    """

    static let minimalUrlExample = "pooplock://wifi?dbm=-59&ssid=HomeWiFi&bssid=AA:BB:CC:DD:EE:FF&rxMbps=866&txMbps=780&noise=-92&channel=44&standard=Wi-Fi%206"
}
