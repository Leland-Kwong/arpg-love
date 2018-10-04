local itemConfig = require("components.item-inventory.items.config")
local msgBus = require("components.msg-bus")
local itemSystem = require("components.item-inventory.items.item-system")
local functional = require("utils.functional")
local AnimationFactory = require 'components.animation-factory'

local weaponCooldown = 0.1

return {
	type = "pod-module-initiate",

	blueprint = {
		baseModifiers = {
			cooldown = {0.1, 0.1},
			attackTime = {0.1, 0.1},
			weaponDamage = {1, 1},
			energyCost = {1, 1}
		},

		extraModifiers = {
			require(require('alias').path.items..'.modifiers.upgrade-force-field')({
				experienceRequired = 120,
				size = 17,
				maxShieldHealth = 30,
				unhitDurationRequirement = 1.5,
			}),
			require(require('alias').path.items..'.modifiers.upgrade-shock')({
				experienceRequired = 10,
				duration = 0.4,
				minDamage = 1,
				maxDamage = 2
			}),
			require(require('alias').path.items..'.modifiers.upgrade-critical-hit')({
				experienceRequired = 40,
				chance = 0.25,
				minMultiplier = 0.2,
				maxMultiplier = 0.4
			}),
			require(require('alias').path.items..'.modifiers.upgrade-bouncing-strike')({
				experienceRequired = 120,
				maxBounces = 1
			})
		},

		experience = 120,
		onActivate = require(require('alias').path.items..'.inventory-actives.equip-on-click')(),
		onActivateWhenEquipped = require(require('alias').path.items..'.equipment-actives.plasma-shot')()
	},

	properties = {
		sprite = "weapon-module-initiate",
		title = 'r-1 initiate',
		baseDropChance = 1,
		category = itemConfig.category.POD_MODULE,

		tooltipItemUpgrade = function(self)
			return upgrades
		end,
	}
}