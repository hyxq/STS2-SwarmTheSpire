using MegaCrit.Sts2.Core.Entities.Cards;
using STS2RitsuLib;
using STS2RitsuLib.Content;
using STS2RitsuLib.Interop.AutoRegistration;
using STS2RitsuLib.Keywords;
using SwarmTheSpire.Cards;

[RegisterOwnedCardKeyword(nameof(Harpoon))]
[RegisterOwnedCardKeyword(nameof(Catch))]
[RegisterOwnedCardTag("harpoon")]
public class SwarmKeyword
{
    public static readonly string Catch = ModContentRegistry.GetQualifiedKeywordId(Const.ModId, "catch");
    public static readonly string Harpoon = ModContentRegistry.GetQualifiedKeywordId(Const.ModId, "harpoon");
}
