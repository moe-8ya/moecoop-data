/**
 * Copyright: Copyright (c) 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.view.config_window;

import dlangui;
import dlangui.dialogs.dialog;

import coop.model.config;
import coop.model.character;
import coop.view.main_frame;
import coop.view.recipe_tab_frame;
import coop.view.recipe_material_tab_frame;

import std.algorithm;
import std.array;
import std.file;
import std.path;

class ConfigDialog: Dialog
{
    this(Window parent, Character[dstring] chars, Config con)
    {
        super(UIString("設定"d), parent, DialogFlag.Popup);
        chars_ = chars;
        config_ = con;
    }

    override void initialize()
    {
        auto wLayout = parseML(q{
                VerticalLayout {
                    padding: 10
                    HorizontalLayout {
                        TextWidget {
                            text: "キャラクター管理"
                        }
                        VerticalLayout {
                            HorizontalLayout {
                                Button {
                                    id: addCharacter
                                    text: "追加..."
                                }
                                Button {
                                    id: deleteCharacter
                                    text: "削除"
                                }
                                Button {
                                    id: editCharacter
                                    text: "キャラクター情報編集..."
                                }
                            }
                            ListWidget {
                                id: characters
                                backgroundColor: "white"
                            }
                        }
                    }
                    HorizontalLayout {
                        TextWidget {
                            text: "Migemo ライブラリ"
                        }
                        FrameLayout {
                            minWidth: 130
                            layoutWidth: FILL_PARENT
                        }
                        Button {
                            id: migemoInstaller
                            text: "インストール"
                        }
                    }
                }
            });

        StringListAdapter charList = new StringListAdapter;
        chars_.keys.each!(c => charList.add(c));
        wLayout.childById!ListWidget("characters").ownAdapter = charList;
        wLayout.childById!ListWidget("characters").selectedItemIndex = 0;
        dstring baseDir = chars_.values.front.baseDirectory;

        if (chars_.keys.length == 1)
        {
            wLayout.childById("deleteCharacter").enabled = false;
        }

        wLayout.childById("addCharacter").click = (Widget src) {
            auto dlg = new CharacterSettingDialog(window, chars_);
            dlg.dialogResult = (Dialog dlg, const Action action) {
                if (action && action.id == StandardAction.Ok)
                {
                    import std.exception;
                    auto cdlg = cast(CharacterSettingDialog)dlg;
                    auto name = enforce(cdlg.charNameBox.text);
                    auto url = cdlg.urlBox.text;
                    chars_[name] = new Character(name, baseDir);
                    // url
                    charList.add(name);
                    auto mainWidget = _parentWindow.mainWidget;
                    with(mainWidget)
                    {
                        childById!RecipeTabFrame("binderFrame").characters = chars_.keys;
                        childById!RecipeTabFrame("skillFrame").characters = chars_.keys;
                        childById!RecipeMaterialTabFrame("materialFrame").characters = chars_.keys;
                    }
                    wLayout.childById("deleteCharacter").enabled = true;
                }
            };
            dlg.show;
            return true;
        };

        wLayout.childById("editCharacter").click = (Widget src) {
            auto list = wLayout.childById!ListWidget("characters");
            auto charIdx = list.selectedItemIndex;
            /// Out of Index の場合は？
            auto charName = charList.items[charIdx].to!dstring;
            auto ch = chars_[charName];
            // auto url = ch.url;

            auto dlg = new CharacterSettingDialog(window, chars_, charName/*, url*/);
            dlg.dialogResult = (Dialog dlg, const Action action) {
                if (action && action.id == StandardAction.Ok)
                {
                    auto url = (cast(CharacterSettingDialog)dlg).urlBox.text;
                    // ch.url = url;
                }
            };
            dlg.show;
            return true;
        };

        wLayout.childById("deleteCharacter").click = (Widget src) {
            auto list = wLayout.childById!ListWidget("characters");
            auto deletedIdx = list.selectedItemIndex;
            /// Out of Index の場合は？
            auto deleted = charList.items[deletedIdx];
            auto c = chars_[deleted];
            chars_.remove(deleted);
            c.deleteConfig;
            charList.remove(deletedIdx);
            auto mainWidget = _parentWindow.mainWidget;
            with(mainWidget)
            {
                childById!RecipeTabFrame("binderFrame").characters = chars_.keys;
                childById!RecipeTabFrame("skillFrame").characters = chars_.keys;
                childById!RecipeMaterialTabFrame("materialFrame").characters = chars_.keys;
            }
            if (chars_.keys.length == 1)
            {
                src.enabled = false;
            }
            // どこかのタイミングで selectedItemIndex を設定する必要あり
            return true;
        };

        if (config_.migemoLib.exists)
        {
            with(wLayout.childById("migemoInstaller"))
            {
                text = "インストール済み";
                enabled = false;
            }
        }
        else
        {
            with(wLayout.childById("migemoInstaller"))
            {
                text = "インストール";
                version(Posix)
                {
                    enabled = false;
                }
                else version(Win32)
                {
                    enabled = false;
                }
            }
        }

        version(Windows)
        {
            wLayout.childById("migemoInstaller").click = (Widget src) {
                wLayout.childById("migemoInstaller").enabled = false;
                childById("close-button").enabled = false;
                scope(exit) childById("close-button").enabled = true;

                wLayout.childById("migemoInstaller").text = "インストール中...";
                scope(success) wLayout.childById("migemoInstaller").text = "インストール済み";
                scope(failure) wLayout.childById("migemoInstallers").text = "インストールに失敗しました";
                installMigemo(config_.migemoLib.dirName);
                return true;
            };
        }

        addChild(wLayout);

        auto exits = new HorizontalLayout;
        auto spacer = new FrameLayout;
        spacer.minWidth(300);
        spacer.layoutWidth(FILL_PARENT);
        exits.addChild(spacer);
        auto close = new Button(ACTION_CLOSE).minWidth(80).text = "閉じる";
        close.id = "close-button";
        exits.addChild(close);
        _buttonActions = [ACTION_CLOSE];
        addChild(exits);
    }

    override void close(const Action action)
    {
        if (action) {
            if (action.id == StandardAction.Close &&
                config_.migemoLib.exists)
            {
                (cast(MainFrame)_parentWindow.mainWidget).controller.loadMigemo;
            }
        }
        _parentWindow.removePopup(_popup);
    }
private:
    Config config_;
    Character[dstring] chars_;
}

auto showConfigWindow(Window parent, Character[dstring] chars, Config config)
{
    auto dlg = new ConfigDialog(parent, chars, config);
    dlg.show;
}

auto installMigemo()(string dest)
{
    version(Windows)
    {
        import std.net.curl;
        import std.format;
        import std.zip;
        import std.file: remove;

        enum baseURL = "http://files.kaoriya.net/cmigemo/";
        enum ver = "20110227";
        version(X86)
        {
            enum arch = "32";
        }
        else
        {
            enum arch = "64";
        }

        auto src = format("%s/cmigemo-default-win%s-%s.zip", baseURL, arch, ver);
        auto archive = src.baseName;
        download(src, archive);
        assert(archive.exists);
        scope(exit) archive.remove;

        unzip(archive, dest);
    }
    else
    {
        static assert(false, "It should not be called from non-Windows systems.");
    }
}

auto unzip(string srcFile, string destDir)
{
    import std.exception;
    import std.regex;
    import std.zip;

    enforce(srcFile.exists);

    auto zip = new ZipArchive(read(srcFile));
    foreach(name, am; zip.directory)
    {
        if (name.endsWith("/"))
        {
            continue;
        }
        auto target = buildPath(destDir, name.replaceFirst(ctRegex!r"^.+?/", ""));
        auto dir = target.dirName;
        mkdirRecurse(dir);
        assert(am.expandedData.length == 0);
        zip.expand(am);
        assert(am.expandedData.length == am.expandedSize);
        target.write(am.expandedData);
    }
}

class CharacterSettingDialog: Dialog
{
    this(Window parent, const Character[dstring] chars, dstring name = "", dstring url = "")
    {
        super(UIString("キャラクター設定"d), parent, DialogFlag.Popup);
        this.name = name;
        this.url = url;
        this.chars = chars;
    }

    override void initialize()
    {
        auto wLayout = parseML(q{
                VerticalLayout {
                    padding: 10
                    TableLayout {
                        colCount: 3
                        TextWidget {
                            text: "キャラクター名"
                        }
                        EditLine {
                            id: charNameBox
                            minWidth: 200
                        }
                        TextWidget {
                            id: "alert"
                            textColor: "red"
                        }
                        TextWidget {
                            text: "URL"
                        }
                        EditLine {
                            id: urlBox
                            minWidth: 200
                            maxWidth: 500
                        }
                        HorizontalLayout {
                            Button {
                                id: ponButton
                                text: "スキるぽん"
                            }
                        }
                    }
                }
            });

        addChild(wLayout);

        if (!name.empty)
        {
            charNameBox.text = name;
            charNameBox.enabled = false;
        }
        charNameBox.contentChange = (EditableContent con) {
            auto txt = con.text;
            if (txt.empty)
            {
                childById("ok-button").enabled = false;
                childById("alert").text = "";
            }
            else if (chars.keys.canFind(txt))
            {
                childById("ok-button").enabled = false;
                childById("alert").text = "既に存在しています";
            }
            else
            {
                childById("ok-button").enabled = true;
                childById("alert").text = "";
            }
        };

        urlBox.text = url;
        urlBox.contentChange = (EditableContent con) {
            import std.regex;
            auto txt = con.text;
            if (charNameBox.enabled && txt.match(ctRegex!r"&%"d))
            {
                import std.uri;
                auto str = txt.matchFirst(ctRegex!r"&(%.+?)$"d)[1];
                charNameBox.text = str.decode.to!dstring;
            }
        };

        childById("ponButton").click = (Widget src) {
            enum PonURL = "http://www.ponz-web.com/skill/";
            Platform.instance.openURL(PonURL);
            return true;
        };

        auto exits = new HorizontalLayout;
        auto spacer = new FrameLayout;
        spacer.minWidth(300);
        spacer.layoutWidth(FILL_PARENT);
        exits.addChild(spacer);
        auto ok = new Button(ACTION_OK).minWidth(80).text = "決定";
        ok.id = "ok-button";
        auto cancel = new Button(ACTION_CANCEL).minWidth(80).text = "キャンセル";
        cancel.id = "cancel-button";
        exits.addChildren([ok, cancel]);
        _buttonActions = [ACTION_OK, ACTION_CANCEL];
        addChild(exits);
    }

    @property auto charNameBox() {
        return cast(EditLine)childById("charNameBox");
    }

    @property auto urlBox() {
        return cast(EditLine)childById("urlBox");
    }
private:
    dstring name;
    dstring url;
    const Character[dstring] chars;
}
