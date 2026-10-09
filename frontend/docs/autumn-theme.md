# Autumn theme

The dashboard retains the APK's header, theme/account controls, personalized greeting, environmental score card, three daily tasks, and footer row (Home, Tracker, central leaf, Community, Ranks). No feature tiles or analytics are added to the home content. Every existing tool remains in the hamburger directory, including the full ecosystem catalog. The center leaf opens that same directory.

The standalone vector tree from the previous change is removed. Full-screen day/night WebP artwork was reconstructed from the approved mockup with ImageGen: amber foliage and an ivory misty landscape by day, copper foliage and a cocoa landscape by night. The artwork appears behind the navigator on every screen; it does not scroll with the cards. It is a reconstruction of the background obscured by UI in the reference, not a claim of pixel-identical extraction.

Shared surface, typography, icon and text tokens use the autumn palette. Lora is bundled under its SIL Open Font License. Existing screen geometry, routes, state and data integrations remain intact.

A transparent, labeled tap area beside the greeting releases a bounded twelve-leaf burst over the background. Leaves never intercept UI gestures. Reduced motion disables all foliage motion, and app lifecycle/TickerMode pause decorative animation.

The Autumn UI workflow runs analysis, tests, actual Flutter screenshot renders for five screens in both appearances, a release web build and an Android release build. Artifacts are `autumn-screen-previews` and `grevidea-autumn-release-apk`.
