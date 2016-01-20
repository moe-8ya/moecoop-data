/**
   MoeCoop
   Copyright (C) 2016  Mojo

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
module coop.migemo.derelict.migemo;

private {
    import derelict.util.loader;
    import derelict.util.system;

    static if (Derelict_OS_Windows)
        enum libNames = "migemo.dll";
    else static if (Derelict_OS_Mac)
        enum libNames = "libmigemo.1.dylib,libmigemo.dylib";
    else static if (Derelict_OS_Posix)
        enum libNames = "libmigemo.so";
    else
        static assert(false, "Need to implement Migemo libNames for this operating system.");
}

/// for migemo_load()
enum MIGEMO_DICTID: int
{
    INVALID   = 0,
    MIGEMO    = 1,
    ROMA2HIRA = 2,
    HIRA2KATA = 3,
    HAN2ZEN   = 4,
    ZEN2HAN   = 5,
}

/// for migemo_set_operator()/migemo_get_operator()
enum MIGEMO_OPINDEX: int
{
    OR         = 0,
    NEST_IN    = 1,
    NEST_OUT   = 2,
    SELECT_IN  = 3,
    SELECT_OUT = 4,
    NEWLINE    = 5,
}

extern(C) {
    alias MIGEMO_PROC_CHAR2INT = int function(const char*, uint*);
    alias MIGEMO_PROC_INT2CHAR = int function(uint, char*);
}

struct migemo;

extern(C) pure nothrow @nogc
{
    alias da_migemo_open = migemo* function(const char* dict);
    alias da_migemo_close = void function(migemo* object);
    alias da_migemo_query = char* function(migemo* object, const(char)* query);
    alias da_migemo_release = void function(migemo* object, char* string);

    alias da_migemo_set_operator = int function(migemo* object, MIGEMO_OPINDEX index, const char* op);
    alias da_migemo_get_operator = const(char)* function(migemo* object, MIGEMO_OPINDEX index);
    alias da_migemo_setproc_char2int = void function(migemo* object, MIGEMO_PROC_CHAR2INT proc);
    alias da_migemo_setproc_int2char = void function(migemo* object, MIGEMO_PROC_INT2CHAR proc);

    alias da_migemo_load = MIGEMO_DICTID function(migemo* obj, MIGEMO_DICTID dict_id, const(char)* dict_file);
    alias da_migemo_is_enable = int function(migemo* obj);
}

__gshared {
    da_migemo_open migemo_open;
    da_migemo_close migemo_close;
    da_migemo_query migemo_query;
    da_migemo_release migemo_release;

    da_migemo_set_operator migemo_set_operator;
    da_migemo_get_operator migemo_get_operator;
    da_migemo_setproc_char2int migemo_setproc_char2int;
    da_migemo_setproc_int2char migemo_setproc_int2char;

    da_migemo_load migemo_load;
    da_migemo_is_enable migemo_is_enable;
}

class DerelictMigemoLoader: SharedLibLoader {
    this() {
        super(libNames);
    }

    protected override void loadSymbols() {
        bindFunc(cast(void**)&migemo_open, "migemo_open");
        bindFunc(cast(void**)&migemo_close, "migemo_close");
        bindFunc(cast(void**)&migemo_query, "migemo_query");
        bindFunc(cast(void**)&migemo_release, "migemo_release");

        bindFunc(cast(void**)&migemo_set_operator, "migemo_set_operator");
        bindFunc(cast(void**)&migemo_get_operator, "migemo_get_operator");
        bindFunc(cast(void**)&migemo_setproc_char2int, "migemo_setproc_char2int");
        bindFunc(cast(void**)&migemo_setproc_int2char, "migemo_setproc_int2char");

        bindFunc(cast(void**)&migemo_load, "migemo_load");
        bindFunc(cast(void**)&migemo_is_enable, "migemo_is_enable");
    }
}

__gshared DerelictMigemoLoader DerelictMigemo;

shared static this() {
    DerelictMigemo = new DerelictMigemoLoader();
}
