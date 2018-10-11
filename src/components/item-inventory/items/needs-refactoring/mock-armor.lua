local config = require("components.item-inventory.items.config")
local functional = require("utils.functional")
local itemSystem =require("components.item-inventory.items.item-system")
local Color = require('modules.color')
local msgBus = require 'components.msg-bus'
local category = config.category.BODY_ARMOR

return {
	type = "mock-armor",

	blueprint = {
		baseModifiers = {
			moveSpeed = 10,
			damage = 5
		},

		extraModifiers = {
			require(require('alias').items..'.modifiers.stat')({
				armor = {1000, 1000},
				maxHealth = {200, 22},
				cooldownReduction = {0.25, 0.25},
				attackTimeReduction = {0.25, 0.25},
				healthRegeneration = {4, 4},
			})
		}
	},

	properties = {
		sprite = "armor_62",
		title = 'Mock ARMOR',
		rarity = config.rarity.NORMAL,
		baseDropChance = 1,
		category = category,

		-- onEquip = function(self)
		-- 	local duration = math.pow(10, 10)
		-- 	local amount = self.healthRegeneration * duration
		-- 	msgBus.send(msgBus.PLAYER_HEAL_SOURCE_ADD, {
		-- 		amount = amount,
		-- 		source = self.source,
		-- 		duration = duration,
		-- 		property = 'health',
		-- 		maxProperty = 'maxHealth'
		-- 	})
		-- end,

		-- onActivate = function(self, rootStore)
		-- 	msgBus.send(msgBus.EQUIPMENT_SWAP, self)
		-- end,

		-- getCalculatedProps = function(self)
		-- 	return self
		-- end,

		-- final = function(self)
		-- 	msgBus.send(msgBus.PLAYER_HEAL_SOURCE_REMOVE, {
		-- 		source = self.source
		-- 	})
		-- end
	}
}