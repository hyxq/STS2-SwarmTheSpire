using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Powers;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.Models;
using STS2RitsuLib.CardTags;
using STS2RitsuLib.Interop.AutoRegistration;
using SwarmTheSpire.Powers;
using SwarmTheSpire;
using STS2RitsuLib.Audio;

namespace SwarmTheSpire.Cards
{
    public sealed class FimSuffix()
        : SwarmEvilPoolCard(1, CardType.Skill, CardRarity.Rare, TargetType.Self, true)
    {
        public override IEnumerable<CardKeyword> CanonicalKeywords => [CardKeyword.Exhaust];

        protected override async Task OnPlay(PlayerChoiceContext choiceContext, CardPlay cardPlay)
        {
            Sts2SfxAlignedFmod.PlayOneShot(Const.Sfx.FIMSuffix);
            await PowerCmd.Apply<FimSuffixPower>(choiceContext, Owner.Creature, 1m, Owner.Creature, this);
        }

        protected override void OnUpgrade() => RemoveKeyword(CardKeyword.Exhaust);
    }
}
