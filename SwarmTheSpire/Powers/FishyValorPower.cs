using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;

namespace SwarmTheSpire.Powers
{
    public sealed class FishyValorPower : SwarmPowerTemplate
    {
        private sealed class Data
        {
            public decimal TrackedGold;
        }

        public override PowerType Type => PowerType.Buff;

        public override PowerStackType StackType => PowerStackType.Single;

        public override string CustomPackedIconPath =>
            "res://SwarmTheSpire/images/powers/SwarmTheSpire-miles_power.png";

        public override string CustomBigIconPath =>
            "res://SwarmTheSpire/images/powers/SwarmTheSpire-miles_power.png";

        protected override object InitInternalData() => new Data();

        public override async Task AfterCardPlayed(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            if (cardPlay.Card.Owner.Creature != Owner)
                return;

            var player = Owner.Player;
            if (player == null)
                return;

            var data = GetInternalData<Data>();
            var currentGold = (decimal)player.Gold;

            if (data.TrackedGold == 0)
            {
                data.TrackedGold = currentGold;
                return;
            }

            var delta = currentGold - data.TrackedGold;
            data.TrackedGold = currentGold;

            if (delta < 0)
            {
                Flash();
                await PowerCmd.Apply<ChargePower>(choiceContext, Owner, Amount, Owner, null);
            }
        }
    }
}
