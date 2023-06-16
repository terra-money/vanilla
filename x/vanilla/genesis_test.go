package vanilla_test

import (
	"testing"

	"github.com/stretchr/testify/require"
	keepertest "github.com/terra-money/vanilla/testutil/keeper"
	"github.com/terra-money/vanilla/testutil/nullify"
	"github.com/terra-money/vanilla/x/vanilla"
	"github.com/terra-money/vanilla/x/vanilla/types"
)

func TestGenesis(t *testing.T) {
	genesisState := types.GenesisState{
		Params: types.DefaultParams(),

		// this line is used by starport scaffolding # genesis/test/state
	}

	k, ctx := keepertest.VanillaKeeper(t)
	vanilla.InitGenesis(ctx, *k, genesisState)
	got := vanilla.ExportGenesis(ctx, *k)
	require.NotNil(t, got)

	nullify.Fill(&genesisState)
	nullify.Fill(got)

	// this line is used by starport scaffolding # genesis/test/assert
}
