module libpb.deserialization;

import std.json;


mixin template T(RecordType)
{
	import std.traits : FieldTypeTuple, FieldNameTuple;
	public RecordType fromJSON(JSONValue jsonIn)
	{
		RecordType record;

		// Alias as to only expand later when used in compile-time
		alias structTypes = FieldTypeTuple!(RecordType);
		alias structNames = FieldNameTuple!(RecordType);
		alias structValues = record.tupleof;

		static foreach(cnt; 0..structTypes.length)
		{
			debug(dbg)
			{
				pragma(msg, structTypes[cnt]);
				pragma(msg, structNames[cnt]);
				// pragma(msg, structValues[cnt]);
			}

			static if(__traits(isSame, mixin(structTypes[cnt]), byte))
			{
				mixin("record."~structNames[cnt]) = cast(byte)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), ubyte))
			{
				mixin("record."~structNames[cnt]) = cast(ubyte)jsonIn[structNames[cnt]].uinteger();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), short))
			{
				mixin("record."~structNames[cnt]) = cast(short)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), ushort))
			{
				mixin("record."~structNames[cnt]) = cast(ushort)jsonIn[structNames[cnt]].uinteger();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), int))
			{
				mixin("record."~structNames[cnt]) = cast(int)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), uint))
			{
				mixin("record."~structNames[cnt]) = cast(uint)jsonIn[structNames[cnt]].uinteger();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), ulong))
			{
				mixin("record."~structNames[cnt]) = cast(ulong)jsonIn[structNames[cnt]].uinteger();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), long))
			{
				mixin("record."~structNames[cnt]) = cast(long)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), string))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].str();

				debug(dbg)
				{
					pragma(msg,"record."~structNames[cnt]);
				}
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), JSONValue))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]];

				debug(dbg)
				{
					pragma(msg,"record."~structNames[cnt]);
				}
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), bool))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].boolean();

				debug(dbg)
				{
					pragma(msg,"record."~structNames[cnt]);
				}
			}
			//FIXME: Not sure how to get array support going, very new to meta programming
			else static if(__traits(isSame, mixin(structTypes[cnt]), mixin(structTypes[cnt])[]))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].boolean();

				debug(dbg)
				{
					pragma(msg,"record."~structNames[cnt]);
				}
			}
			else
			{
				// throw new
				//TODO: Throw error
				debug(dbg)
				{
					pragma(msg, "Unknown type for de-serialization");
				}
			}
		}

		return record;
	}
}

unittest
{
	import std.string : cmp;
	import std.stdio : writeln;
	
	struct Person
	{
		public string firstname, lastname;
		public int age;
		public bool isMale;
		public JSONValue obj;
		public int[] list;
	}
	
	JSONValue json = parseJSON(`{
"firstname" : "Tristan",
"lastname": "Kildaire",
"age": 23,
"obj" : {"bruh":1},
"isMale": true,
"list": [1,2,3]
}
`);

	mixin T!(Person);
	Person person = fromJSON(json);

	debug(dbg)
	{
		writeln(person);	
	}

	assert(cmp(person.firstname, "Tristan") == 0);
	assert(cmp(person.lastname, "Kildaire") == 0);
	assert(person.age == 23);
	assert(person.isMale == true);
	assert(person.obj["bruh"].integer() == 1);
	//TODO: list test case
}
