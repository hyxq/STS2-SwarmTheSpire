using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.MonsterMoves.Intents;
using MegaCrit.Sts2.Core.ValueProps;
using STS2RitsuLib.CardTags;
using SwarmTheSpire;

namespace SwarmTheSpire.Cards
{
    public sealed class TungstenCubes()
        : SwarmEvilPoolCard(2, CardType.Skill, CardRarity.Uncommon, TargetType.AnyEnemy, true)
    {
        protected override IEnumerable<IHoverTip> AdditionalHoverTips =>
        [StunIntent.GetStaticHoverTip(),
        HoverTipFactory.FromKeyword(CardKeyword.Exhaust)];


        protected override IEnumerable<DynamicVar> CanonicalVars =>
        [
            new("Gold", -21m),
        ];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            ArgumentNullException.ThrowIfNull(cardPlay.Target);

            await PlayerCmd.GainGold(DynamicVars["Gold"].IntValue, Owner);

            await CreatureCmd.Stun(cardPlay.Target);

            if (Owner.Gold < 0)
                await CardCmd.Exhaust(choiceContext, this);
        }

        protected override void OnUpgrade()
        {
            EnergyCost.UpgradeBy(-1);
        }
    }
}
