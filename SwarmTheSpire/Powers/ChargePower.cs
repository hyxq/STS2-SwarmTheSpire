using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Content;
using STS2RitsuLib.Keywords;
using SwarmTheSpire.Cards;

namespace SwarmTheSpire.Powers;

public sealed class ChargePower : SwarmPowerTemplate
{
    public override PowerType Type => PowerType.Buff;

    public override PowerStackType StackType => PowerStackType.Counter;

    public override bool AllowNegative => true;

    protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [
            HoverTipFactory.FromCard<Harpoon>(),
        ];


    public override decimal ModifyDamageAdditive(Creature? target, decimal amount, ValueProp props, Creature? dealer,
        CardModel? cardSource)
	{
		if (base.Owner != dealer)
			return 0m;

        if (cardSource is null || !cardSource.HasModCardTag(SwarmCardTagIds.Harpoon))
			return 0m;
		return base.Amount;
	}	

    protected override IEnumerable<string> RegisteredKeywordIds =>
        [
            SwarmKeywords.Harpoon,
        ];

    public override async Task AfterPowerAmountChanged(PlayerChoiceContext choiceContext, PowerModel power,
        decimal amount, Creature? applier, CardModel? cardSource)
    {
        if (!ReferenceEquals(power, this) || Amount <= 0)
            return;

        var player = Owner.Player;
        if (player is null)
            return;

        var handCards = player.PlayerCombatState?.Hand.Cards;
        if (handCards is not null && handCards.Any(static c => c is Harpoon))
            return;

        var combatState = Owner.CombatState;
        if (combatState is null)
            return;

        var created = CardFactory.GetForCombat(player, [ModelDb.Card<Harpoon>()], 1,
            player.RunState.Rng.CombatCardGeneration);
        await CardPileCmd.AddGeneratedCardsToCombat(created, PileType.Hand, player, CardPilePosition.Top);
    }

    public override async Task AfterCardPlayed(PlayerChoiceContext context, CardPlay cardPlay)
    {
        if (cardPlay.Card.Owner.Creature != Owner)
            return;

        if (!cardPlay.Card.HasModCardTag(SwarmCardTagIds.Harpoon))
            return;

        await PowerCmd.Remove(this);
    }
}