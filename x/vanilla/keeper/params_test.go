package keeper_test

import (
	"testing"

	"github.com/stretchr/testify/require"
	testkeeper "github.com/terra-money/vanilla/testutil/keeper"
	"github.com/terra-money/vanilla/x/vanilla/types"
)

func TestGetParams(t *testing.T) {
	k, ctx := testkeeper.VanillaKeeper(t)
	params := types.DefaultParams()

	k.SetParams(ctx, params)

	require.EqualValues(t, params, k.GetParams(ctx))
}
