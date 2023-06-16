package keeper

import (
	"github.com/terra-money/vanilla/x/vanilla/types"
)

var _ types.QueryServer = Keeper{}
