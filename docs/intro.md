---
sidebar_position: 1
---

# Getting Started

**NOTE**: If you'd prefer to use the module without all the features, we highly recommend looking at the [Vibez Ranking](https://itsrune.github.io/VibezRanking) module. (Recommended for application centers, etc.)

### Installation

#### Method 1 (Recommended)

The main pro of this method is that you get auto-updates and you don't have to worry about updating the module yourself.

1. Get the free [Module](https://www.roblox.com/library/14946453963/Vibez)
2. Create a script in ServerScriptService and put `require(14946453963)("Your_Api_Key_Here")` to fetch the module
3. Done!

#### Method 2

<!-- **Due to Roblox taking down our module, this will be the only method while we attempt to get our module back up.** <br /> -->
This method is recommended if you'd like more control over our module. With this method, you also get the benefit of using the latest typed methods/variables.

1. Get the free [Module](https://www.roblox.com/library/14946453963/Vibez)
2. Rename the module to `Vibez`.
3. Insert the module into `ServerScriptService`
4. Create a script in ServerScriptService and put `require(game:GetService("ServerScriptService").Vibez)("Your_Api_Key_Here")` to fetch the module within your script
    - Anywhere you see `require(14946453963)` in the documentation, replace it with `require(game:GetService("ServerScriptService").Vibez)`
5. Done!

<!-- TODO: Update the version everytime you update! -->
<!-- 1. Download the [Module](https://github.com/ItsRune/Vibez/releases/latest)
2. Insert the module into `ServerScriptService`
3. Use `require(game:GetService("ServerScriptService").Vibez)` to fetch the module within your script
    - Anywhere you see `require(game:GetService("ServerScriptService").Vibez)` in the documentation, replace it with `require(game:GetService("ServerScriptService").Vibez)`
4. Done! -->

---

Our module has different settings that can fit to suit your needs. Keep reading to the next page about our settings.