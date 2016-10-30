/**
 * Copyright: Copyright (c) 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.util;

import std.json;
import std.range;
import std.string;
import std.traits;

/// 各種データファイルが置いてあるディレクトリ
immutable SystemResourceBase = "resource";

/// ユーザーの設定ファイルが置いてあるディレクトリ
immutable UserResourceBase = "userdata";

/// プログラム名
immutable AppName = "生協の知恵袋"d;

/// バージョン番号
immutable Version = import("version").chomp;

/// 公式サイト URL
enum MoeCoopURL = "http://docs.fukuro.coop.moe/";

/**
 * バージョン番号 `var` がリリース版を表しているかを返す。
 * リリース版の番号は、`v.a.b.c` となっている (`a`, `b`, `c` は数字)。
 * Returns: `var` がリリース版を表していれば `true`、それ以外は `false`
 */
@property auto isRelease(in string ver) @safe pure nothrow
{
    import std.algorithm;
    return !ver.canFind("-");
}

///
@safe pure nothrow unittest
{
    assert(!"v1.0.2-2-norelease".isRelease);
    assert("v1.0.2".isRelease);
}

///
struct EventHandler(T...)
{
    ///
    void opCall(T args) {
        if (proc == Proc.init)
        {
            // nop
        }
        else
        {
            proc(args);
        }
    }

    ///
    auto opAssign(Proc p) @safe pure nothrow
    {
        proc = p;
        return p;
    }
private:
    alias Proc = void delegate(T);
    Proc proc;
}

nothrow unittest
{
    import std.exception;
    EventHandler!int eh1;
    assertNotThrown(eh1(0));

    EventHandler!int eh2;
    eh2 = (int x) { /* nop */ };
    assertNotThrown(eh2(0));
}

///
auto indexOf(Range, Elem)(Range r, Elem e)
    if (isInputRange!Range && is(Elem: ElementType!Range) && !isSomeChar!(ElementType!Range))
{
    import std.algorithm;
    auto elm = r.enumerate.find!"a[1] == b"(e);
    return elm.empty ? -1 : elm.front[0];
}

///
@safe pure nothrow unittest
{
    assert([1, 2, 3, 4].indexOf(2) == 1);
    assert([1, 2, 3, 4].indexOf(5) == -1);
}

/**
 * 双方向マップ
 */
struct BiMap(T, U)
{
    ///
    this(const T[U] kvs)
    in{
        import std.algorithm;
        auto len = kvs.keys.length;
        auto keys = kvs.keys.sort().uniq.array;
        assert(keys.length == len);
        auto vals = kvs.values.dup.sort().uniq.array;
        assert(vals.length == len);
    } body {
        import std.algorithm;
        import std.typecons;
        fmap = kvs;
        bmap = kvs.byKeyValue().map!(kv => tuple(kv.value, kv.key)).assocArray;
    }

    ///
    auto opBinaryRight(string op)(U key)
        @safe const pure nothrow if (op == "in")
    {
        return key in fmap;
    }

    ///
    auto opBinaryRight(string op)(T key)
        @safe const pure nothrow if (op == "in")
    {
        return key in bmap;
    }

    ///
    auto ref opIndex(U k) const pure nothrow
    in {
        assert(k in fmap);
    } body {
        return fmap[k];
    }

    ///
    auto ref opIndex(T k) const pure nothrow
    in {
        assert(k in bmap);
    } body {
        return bmap[k];
    }
private:
    const T[U] fmap;
    const U[T] bmap;
}

///
struct ExtendedEnum(KVs...)
{
    import std.meta;
    mixin(format(q{
                enum{
                    %s
                }
            }, [staticMap!(ParamName, KVs)].join(", ")));
    ///
    enum svalues = [staticMap!(ReturnValue, KVs)];
    ///
    enum values = mixin("["~[staticMap!(ParamName, KVs)].join(", ")~"]");

    int val;
    alias val this;

    ///
    this(int m) @safe nothrow
    in {
        assert(m in bimap);
    } body {
        val = m;
    }

    ///
    this(S)(S s) @safe nothrow if (isSomeString!S)
    in {
        import std.format;
        assert(s in bimap, format("%s は EEnum %s に含まれていません", s, bimap));
    } body {
        val = bimap[s];
    }

    ///
    auto toString() @safe const nothrow
    {
        return bimap[val];
    }

private:
    // _aaRange cannot be interpreted at compile time
    static const BiMap!(string, int) bimap;
    static this()
    {
        bimap = zip(values, svalues).assocArray;
    }

    invariant
    {
        assert(val in bimap);
    }
}

private enum ReturnValue(alias T) = T!string("");

private enum ParamName(alias T) = {
    import std.string: indexOf;
    auto str = typeof(T!string).stringof;
    str = str[str.indexOf("function(string ") + "function(string ".length .. $];
    return str[0 .. str.indexOf(")")];
}();

version(unittest)
{
    ///
    alias util_EEnum = ExtendedEnum!(
        A => "い", B => "ろ", C => "は",
        );
}
///
@safe nothrow unittest
{
    import std.conv;
    import std.exception;
    static assert(util_EEnum.values == [util_EEnum.A, util_EEnum.B, util_EEnum.C]);
    static assert(util_EEnum.svalues == ["い", "ろ", "は"]);

    util_EEnum val = util_EEnum.A;
    assert(assertNotThrown(val.to!string) == "い");
    assert("い".to!util_EEnum == val);
}

/**
 * JSONValue から他の方への変換を行う。
 * Params: T = 変換後の型
 *         json = 変換を行う JSONValue
 */
auto jto(T)(JSONValue json)
{
    import std.conv;
    import std.exception;
    static if (isSomeString!T || is(T == enum))
    {
        enforce(json.type == JSON_TYPE.STRING);
        // JSONValue#str is not safe until 2.071.0
        auto s = () @trusted { return json.str; }();
        return s.to!T;
    }
    else static if (isIntegral!T)
    {
        enforce(json.type == JSON_TYPE.INTEGER);
        return json.integer.to!T;
    }
    else static if (isFloatingPoint!T)
    {
        enforce(json.type == JSON_TYPE.FLOAT || json.type == JSON_TYPE.INTEGER);
        return json.type == JSON_TYPE.FLOAT ? json.floating.to!T :
            json.integer.to!T;
    }
    else static if (isAssociativeArray!T)
    {
        enforce(json.type == JSON_TYPE.OBJECT);
        return json.object.jto!T;
    }
    else static if (isArray!T)
    {
        enforce(json.type == JSON_TYPE.ARRAY, "Invalid value: "~json.to!string);
        return json.array.jto!T;
    }
    else static if (is(T == bool))
    {
        enforce(json.type == JSON_TYPE.TRUE ||
                json.type == JSON_TYPE.FALSE);
        return json.type == JSON_TYPE.TRUE;
    }
    else static if (__traits(isSame, TemplateOf!T, ExtendedEnum))
    {
        enforce(json.type == JSON_TYPE.STRING);
        // JSONValue#str is not safe until 2.071.0
        auto s = () @trusted { return json.str; }();
        return s.to!T;
    }
    else
    {
        static assert(false, "Fail to T: "~T.stringof);
    }
}

/// ditto
auto jto(AA: V[K], V, K)(JSONValue[string] json)
{
    import std.algorithm;
    import std.conv;
    import std.typecons;
    return json.keys.map!(k => tuple(k.to!K, json[k].jto!V)).assocArray;
}

/// ditto
auto jto(Array: T[], T)(JSONValue[] json)
    if (!isSomeString!Array)
{
    import std.algorithm;
    return json.map!(jto!T).array;
}

///
@safe nothrow unittest
{
    import std.conv;
    import std.exception;

    // 各種プリミティブ型への変換
    {
        auto i = 3;
        auto ival = JSONValue(i);
        assert(assertNotThrown(ival.jto!int) == i);
    }

    {
        auto s = "foobar";
        auto sval = JSONValue(s);
        assert(assertNotThrown(sval.jto!string) == s);
    }

    {
        auto f = 3.14;
        auto fval = JSONValue(f);
        assert(assertNotThrown(fval.jto!real) == f);
    }

    // JSONValue(int) -> real への変換
    {
        auto i = 3;
        auto fval = JSONValue(i);
        assert(assertNotThrown(fval.jto!real) == i.to!real);
    }

    // ユーザー定義型への変換
    {
        enum E { A, B, C }
        auto e = E.A;
        auto eval = JSONValue(assertNotThrown((e.to!string)));
        assert(assertNotThrown(eval.jto!E) == e);
    }

    {
        util_EEnum e = util_EEnum.A;
        auto eval = JSONValue(assertNotThrown(e.to!string));
        assert(assertNotThrown(eval.jto!util_EEnum) == e);
    }
}

/**
 * デバッグビルド時に、key の重複時にエラー出力にその旨を表示する std.array.assocArray
 * リリースビルド時には std.array.assocArray をそのまま呼び出す。
 */
auto checkedAssocArray(Range)(Range r) if (isInputRange!Range)
{
    debug
    {
        import std.algorithm;
        import std.traits;
        import std.typecons;
        alias E = ElementType!Range;
        static assert(isTuple!E, "assocArray: argument must be a range of tuples");
        static assert(E.length == 2, "assocArray: tuple dimension must be 2");
        alias KeyType = E.Types[0];
        alias ValueType = E.Types[1];

        ValueType[KeyType] ret;
        return r.fold!((r, kv) {
                auto key = kv[0];
                auto val = kv[1];
                if (auto it = key in r)
                {
                    import dlangui.core.logger;
                    Log.fd("キーが重複しています: %s", key);
                    static if (hasMember!(ValueType, "file") && is(typeof(ValueType.init.file) == string))
                    {
                        Log.fd(" (%s, %s)", (*it).file, val.file);
                    }
                }
                r[key] = val;
                return r;
            })(ret);
    }
    else
    {
        return r.assocArray;
    }
}

/**
 * 入力文字列の全角カタカナを半角カタカナに変換した文字列を返す
 * Note: std.string.tarnslate は濁点を含む全角カタカナを処理できない
 */
@property auto toHankaku(dstring str) @safe
{
    static dstring trans(dchar c)
    {
        switch(c)
        {
        case 'ア': return "ｱ"; case 'イ': return "ｲ"; case 'ウ': return "ｳ"; case 'エ': return "ｴ"; case 'オ': return "ｵ";
        case 'カ': return "ｶ"; case 'キ': return "ｷ"; case 'ク': return "ｸ"; case 'ケ': return "ｹ"; case 'コ': return "ｺ";
        case 'サ': return "ｻ"; case 'シ': return "ｼ"; case 'ス': return "ｽ"; case 'セ': return "ｾ"; case 'ソ': return "ｿ";
        case 'タ': return "ﾀ"; case 'チ': return "ﾁ"; case 'ツ': return "ﾂ"; case 'テ': return "ﾃ"; case 'ト': return "ﾄ";
        case 'ナ': return "ﾅ"; case 'ニ': return "ﾆ"; case 'ヌ': return "ﾇ"; case 'ネ': return "ﾈ"; case 'ノ': return "ﾉ";
        case 'ハ': return "ﾊ"; case 'ヒ': return "ﾋ"; case 'フ': return "ﾌ"; case 'ヘ': return "ﾍ"; case 'ホ': return "ﾎ";
        case 'マ': return "ﾏ"; case 'ミ': return "ﾐ"; case 'ム': return "ﾑ"; case 'メ': return "ﾒ"; case 'モ': return "ﾓ";
        case 'ヤ': return "ﾔ"; case 'ユ': return "ﾕ"; case 'ヨ': return "ﾖ";
        case 'ラ': return "ﾗ"; case 'リ': return "ﾘ"; case 'ル': return "ﾙ"; case 'レ': return "ﾚ"; case 'ロ': return "ﾛ";
        case 'ワ': return "ﾜ"; case 'ヲ': return "ｦ"; case 'ン': return "ﾝ";

        case 'ー': return "ｰ";

        case 'ァ': return "ｧ"; case 'ィ': return "ｨ"; case 'ゥ': return "ｩ"; case 'ェ': return "ｪ"; case 'ォ': return "ｫ";
        case 'ャ': return "ｬ"; case 'ュ': return "ｭ"; case 'ョ': return "ｮ";

        case 'ガ': return "ｶﾞ"; case 'ギ': return "ｷﾞ"; case 'グ': return "ｸﾞ"; case 'ゲ': return "ｹﾞ"; case 'ゴ': return "ｺﾞ";
        case 'ザ': return "ｻﾞ"; case 'ジ': return "ｼﾞ"; case 'ズ': return "ｽﾞ"; case 'ゼ': return "ｾﾞ"; case 'ゾ': return "ｿﾞ";
        case 'ダ': return "ﾀﾞ"; case 'ヂ': return "ﾁﾞ"; case 'ヅ': return "ﾂﾞ"; case 'デ': return "ﾃﾞ"; case 'ド': return "ﾄﾞ";
        case 'バ': return "ﾊﾞ"; case 'ビ': return "ﾋﾞ"; case 'ブ': return "ﾌﾞ"; case 'ベ': return "ﾍﾞ"; case 'ボ': return "ﾎﾞ";
        case 'パ': return "ﾊﾟ"; case 'ピ': return "ﾋﾟ"; case 'プ': return "ﾌﾟ"; case 'ペ': return "ﾍﾟ"; case 'ポ': return "ﾎﾟ";
        default:   return [c];
        }
    }
    import std.algorithm;
    return str.map!trans.join;
}

///
@safe unittest
{
    assert("アカサタナハマヤラワ".toHankaku == "ｱｶｻﾀﾅﾊﾏﾔﾗﾜ");
    assert("ァャガザダバパ".toHankaku == "ｧｬｶﾞｻﾞﾀﾞﾊﾞﾊﾟ");
    assert("ソート後の表".toHankaku == "ｿｰﾄ後の表");

    // - (ハイフン) と ｰ (半角カタカナ) は似ているが違うので注意！
    assert("ソート後の表".toHankaku != "ｿ-ﾄ後の表");
}

version(D_Coverage)
{
    version(unittest)
    {
        extern(C) int UIAppMain(string[] args) {
            return 0;
        }
    }
}
