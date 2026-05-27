using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.Factories;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using SwarmTheSpire.Cards;

namespace SwarmTheSpire.Powers
{
    /// <summary>
    /// After Advent is played, counts down 12 cards then adds BirthdayDot to hand.
    /// </summary>
    public sealed class AdventInitialTrackingPower : SwarmPowerTemplate
    {
        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Counter;

        public override string CustomPackedIconPath => Const.Paths.SharedPowerIcon;

        public override async Task AfterCardPlayed(PlayerChoiceContext context, CardPlay cardPlay)
        {
            if (cardPlay.Card.Owner.Creature != Owner)
                return;

            if (cardPlay.Card is Advent || cardPlay.Card is BirthdayDot || cardPlay.Card is BirthdayExclaim)
                return;

            await PowerCmd.Decrement(this);

            if (Amount > 0)
                return;

            var player = Owner.Player;
            if (player is null)
                return;

            var birthdayDot = CardFactory.GetForCombat(player, [ModelDb.Card<BirthdayDot>()], 1,
                player.RunState.Rng.CombatCardGeneration);
            await CardPileCmd.AddGeneratedCardsToCombat(birthdayDot, PileType.Hand, player, CardPilePosition.Top);

            await PowerCmd.Remove(this);
        }
    }
}
