import Foundation
import Testing
@testable import ClipDeck

/// `GlossaryHTML`: Yomitan glossary items to safe HTML.
struct GlossaryHTMLTests {
    func html(_ json: String) -> String { GlossaryHTML.html(structured: Data(json.utf8)) }

    @Test func plainTextBecomesAnEscapedBulletList() {
        let out = GlossaryHTML.html([.text("healthy"), .text("a & b <i>")])
        #expect(out == "<ul><li>healthy</li><li>a &amp; b &lt;i&gt;</li></ul>")
    }

    @Test func textAndStructuredItemsKeepTheirOrder() {
        let items: [GlossaryItem] = [.text("a"), .structured(Data(#"{"tag":"div","content":"x"}"#.utf8)), .text("b")]
        #expect(GlossaryHTML.html(items) == "<ul><li>a</li></ul><div><div>x</div></div><ul><li>b</li></ul>")
    }

    @Test func escapesEverySpecialCharacter() {
        #expect(GlossaryHTML.escape(#"a & b < c > d "e" 'f'"#) == "a &amp; b &lt; c &gt; d &quot;e&quot; &#39;f&#39;")
        #expect(html(#""<script>alert(1)</script>""#) == "&lt;script&gt;alert(1)&lt;/script&gt;")
    }

    @Test func keepsRuby() {
        #expect(html(#"{"tag":"ruby","content":["漢字",{"tag":"rp","content":"("},{"tag":"rt","content":"かんじ"},{"tag":"rp","content":")"}]}"#)
            == "<ruby>漢字<rp>(</rp><rt>かんじ</rt><rp>)</rp></ruby>")
    }

    @Test func keepsNestedLists() {
        let json = #"{"tag":"ul","content":[{"tag":"li","content":["a",{"tag":"ol","content":[{"tag":"li","content":"b"}]}]}]}"#
        #expect(html(json) == "<ul><li>a<ol><li>b</li></ol></li></ul>")
    }

    @Test func keepsATable() {
        let json = #"{"tag":"table","content":[{"tag":"thead","content":{"tag":"tr","content":[{"tag":"th","content":"H"}]}},"#
            + #"{"tag":"tbody","content":{"tag":"tr","content":[{"tag":"td","content":"c"}]}}]}"#
        #expect(html(json) == "<table><thead><tr><th>H</th></tr></thead><tbody><tr><td>c</td></tr></tbody></table>")
    }

    @Test func keepsDetailsAndSummary() {
        #expect(html(#"{"tag":"details","content":[{"tag":"summary","content":"More"},"body"]}"#)
            == "<details><summary>More</summary>body</details>")
    }

    @Test func aLinkIsShownAsItsTextOnly() {
        let out = html(#"{"tag":"a","href":"https://example.com/x","content":["see ",{"tag":"span","content":"this"}]}"#)
        #expect(out == "see <span>this</span>")
        #expect(!out.contains("href"))
        #expect(!out.contains("example.com"))
    }

    @Test func scriptsAndEventHandlersAreInert() {
        #expect(html(#"{"tag":"script","content":"alert(1)"}"#) == "")
        let out = html(#"{"tag":"span","onclick":"alert(1)","onmouseover":"x","content":"hi"}"#)
        #expect(out == "<span>hi</span>")
        #expect(html(#"{"tag":"iframe","src":"https://example.com","content":"inner"}"#) == "inner")
        #expect(html(#"{"tag":"div onclick=alert(1)","content":"x"}"#) == "x")
    }

    @Test func imagesAreDropped() {
        #expect(html(#"{"tag":"img","path":"a.png","content":"alt","width":1}"#) == "")
        #expect(html(#"["a",{"tag":"img","path":"x.png"},"b"]"#) == "ab")
    }

    @Test func keepsOnlyTheAllowedStyles() {
        let json = #"{"tag":"span","style":{"fontWeight":"bold","fontStyle":"italic","textDecorationLine":["underline","overline"],"#
            + #""fontSize":"1.2em","listStyleType":"square","verticalAlign":"super","color":"red","position":"fixed"},"content":"x"}"#
        #expect(html(json)
            == "<span style='font-weight:bold;font-style:italic;text-decoration:underline;font-size:1.2em;list-style-type:square;vertical-align:super'>x</span>")
    }

    @Test func dropsStyleValuesThatAreNotOnTheAllowList() {
        let json = #"{"tag":"span","style":{"fontWeight":"bold;color:red","fontSize":"999em","listStyleType":"url(x)","verticalAlign":"10px"},"content":"x"}"#
        #expect(html(json) == "<span>x</span>")
        #expect(html(#"{"tag":"span","style":{"fontSize":"nanem"},"content":"x"}"#) == "<span>x</span>")
        #expect(html(#"{"tag":"span","style":{"textDecorationLine":"line-through"},"content":"x"}"#)
            == "<span style='text-decoration:line-through'>x</span>")
    }

    @Test func aBreakStaysABreak() {
        #expect(html(#"["a",{"tag":"br"},"b"]"#) == "a<br>b")
    }

    @Test func aTooDeepTreeIsCutOff() {
        let depth = 200
        let json = String(repeating: #"{"tag":"div","content":"#, count: depth) + #""x""# + String(repeating: "}", count: depth)
        let out = html(json)
        #expect(out.components(separatedBy: "<div>").count - 1 < depth)
        #expect(!out.contains("x"))
    }

    @Test func badJSONGivesNothing() {
        #expect(html("not json") == "")
        #expect(html("") == "")
        #expect(html("{}") == "")
        #expect(html("5") == "")
    }
}
