local Component = require 'modules.component'
local config = require("components.item-inventory.items.config")
local msgBus = require("components.msg-bus")
local itemDefs = require("components.item-inventory.items.item-definitions")
local Color = require 'modules.color'
local functional = require("utils.functional")
local AnimationFactory = require 'components.animation-factory'
local setProp = require 'utils.set-prop'
local Sound = require 'components.sound'

local bulletColor = {Color.rgba255(252, 122, 255)}

local function statValue(stat, color, type)
	local sign = stat >= 0 and "+" or "-"
	return {
		color, sign..stat..' ',
		{1,1,1}, type
	}
end

local function concatTable(a, b)
	for i=1, #b do
		local elem = b[i]
		table.insert(a, elem)
	end
	return a
end

return itemDefs.registerType({
	type = "pod-one",

	create = function()
		return {
			stackSize = 1,
			maxStackSize = 1,

			-- static properties
			weaponDamage = 1,
			experience = 0
		}
	end,

	properties = {
		sprite = "weapon-module-initiate",
		title = 'r-1 initiate',
		rarity = config.rarity.NORMAL,
		category = config.category.POD_MODULE,

		energyCost = function(self)
			return 1
		end,

		tooltip = function(self)
			local stats = {
				statValue(self.weaponDamage, Color.CYAN, "damage \n")
			}
			return functional.reduce(stats, concatTable, {})
		end,

		tooltipItemUpgrade = function(self)
			return {
				{
					sprite = 'item-upgrade-placeholder-unlocked',
					title = 'Shock',
					description = 'Attacks shock the target, dealing 1-2 lightning damage and briefly stunning them for 0.1s.',
					experienceRequired = 10
				},
				{
					sprite = 'item-upgrade-placeholder-unlocked',
					title = 'Critical Strikes',
					description = 'Attacks have a 25% chance to deal 2x damage',
					experienceRequired = 40
				},
				{
					sprite = 'item-upgrade-placeholder-unlocked',
					title = 'Bouncing Strikes',
					description = 'Attacks bounce to 2 other targets, dealing 50% less damage each bounce.',
					experienceRequired = 120
				}
			}
		end,

		onEquip = function(self)
			local msgTypes = {
				[msgBus.EQUIPMENT_UNEQUIP] = function(v)
					return msgBus.CLEANUP
				end,
				[msgBus.ENEMY_DESTROYED] = function(v)
					self.experience = self.experience + v.experience
				end
			}

			msgBus.subscribe(function(msgType, msgValue)
				local handler = msgTypes[msgType]
				if handler then
					handler(msgValue)
				end
			end)
		end,

		onActivate = function(self)
			local toSlot = itemDefs.getDefinition(self).category
			msgBus.send(msgBus.EQUIPMENT_SWAP, self)
		end,

		onActivateWhenEquipped = function(self, props)
			local Projectile = require 'components.abilities.bullet'
			love.audio.stop(Sound.PLASMA_SHOT)
			love.audio.play(Sound.PLASMA_SHOT)
			return Projectile.create(
				setProp(props)
					:set('minDamage', 1)
					:set('maxDamage', 3)
					:set('color', bulletColor)
					:set('targetGroup', 'ai')
					:set('startOffset', 26)
					:set('speed', 400)
			)
		end,

		modifier = function(self, msgType, msgValue)
			if msgBus.PLAYER_ATTACK == msgType then
				msgValue.flatDamage = self.state.bonusDamage
			end
			return msgValue
		end,
	}
})