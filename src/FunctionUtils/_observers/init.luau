--!strict

-- Modified sleitnick observers plus some extra observers
-- https://github.com/Sleitnick/RbxObservers

return {
	observeAttribute = require(script._observeAttribute),
	observeAttributes = require(script._observeAttributes),
	observeAllAttributes = require(script._observeAllAttributes),
	observeCharacter = require(script._observeCharacter),
	observeLocalCharacter = require(script._observeLocalCharacter),
	observePlayer = require(script._observePlayer),
	observeProperty = require(script._observeProperty),
	observeTag = require(script._observeTag),
	observeChildren = require(script._observeChildren),
	observeDescendants = require(script._observeDescendants),
	observeAncestry = require(script._observeAncestry)
}