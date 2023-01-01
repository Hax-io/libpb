module libpb;

import std.json;
import std.stdio;
import std.net.curl;
import std.conv : to;
import std.string : cmp;

public class PBException : Exception
{	
	this()
	{
		super("bruh todo");
	}
}

public final class RecordNotFoundException : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;
	}
}

public final class NotAuthorized : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;
	}
}

public final class ValidationRequired : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;
	}
}



public final class NetworkException : PBException
{
	this()
	{

	}
}

public final class PocketBaseParsingException : PBException
{

}

public class PocketBase
{
	private string pocketBaseURL;
	
	/** 
	 * Constructs a new PocketBase instance with
	 * the default settings
	 */
	this(string pocketBaseURL = "http://127.0.0.1:8090/api/")
	{
		this.pocketBaseURL = pocketBaseURL;
	}

	/** 
	 * List all of the records in the given table
	 *
	 * Params:
	 *   table = the table to list from
	 *   page = the page to look at (default is 1)
	 *   perPage = the number of items to return per page (default is 30)
	 *
	 * Returns: A list of type <code>RecordType</code>
	 */
	public RecordType[] listRecords(RecordType)(string table, ulong page = 1, ulong perPage = 30, string filter = "")
	{
		RecordType[] recordsOut;

		// Compute the query string
		string queryStr = "page="~to!(string)(page)~"&perPage="~to!(string)(perPage);
		queryStr ~= cmp(filter, "") == 0 ? "" : "&filter="~filter;
		
		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records?"~queryStr);
			JSONValue responseJSON = parseJSON(responseData);
			JSONValue[] returnedItems = responseJSON["items"].array();
			foreach(JSONValue returnedItem; returnedItems)
			{
				recordsOut ~= fromJSON!(RecordType)(returnedItem);
			}
			
			return recordsOut;
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Creates a record in the given table
	 *
	 * Params:
	 *   table = the table to create the record in
	 *   item = The Record to create
	 *
	 * Returns: An instance of the created <code>RecordType</code>
	 */
	public RecordType createRecord(string, RecordType)(string table, RecordType item, bool isAuthCollection = false)
	{
		idAbleCheck(item);

		RecordType recordOut;
		
		HTTP httpSettings = HTTP();
		httpSettings.addRequestHeader("Content-Type", "application/json");
		
		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)post(pocketBaseURL~"collections/"~table~"/records", serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			
			// On creation of a record in an "auth" collection the email visibility
			// will initially be false, therefore fill in a blank for it temporarily
			// now as to not make `fromJSON` crash when it sees an email field in
			// a struct and tries to look the the JSON key "email" when it isn't present
			//
			// A password is never returned (so `password` and `passwordConfirm` will be left out)
			//
			// The above are all assumed to be strings, if not then a runtime error will occur
			// See (issue #3)
			if(isAuthCollection)
			{
				responseJSON["email"] = "";
				responseJSON["password"] = "";
				responseJSON["passwordConfirm"] = "";
			}
			
			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 403)
			{
				throw new NotAuthorized(table, item.id);
			}
			else if(e.status == 400)
			{
				throw new ValidationRequired(table, item.id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * View the given record by id
	 *
	 * Params:
	 *   table = the table to lookup the record in
	 *   id = the id to lookup the record by
	 *
	 * Returns: The found record of type <code>RecordType</code>
	 */
	public RecordType viewRecord(RecordType)(string table, string id)
	{
		RecordType recordOut;

		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records/"~id);
			JSONValue responseJSON = parseJSON(responseData);

			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Updates the given record in the given table, returning the
	 * updated record
	 *
	 * Params:
	 *   table = tabe table to update the record in
	 *   item = the record of type <code>RecordType</code> to update
	 *
	 * Returns: The updated <code>RecordType</code>
	 */
	public RecordType updateRecord(string, RecordType)(string table, RecordType item)
	{
		idAbleCheck(item);

		RecordType recordOut;
		
		HTTP httpSettings = HTTP();
		httpSettings.addRequestHeader("Content-Type", "application/json");

		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)patch(pocketBaseURL~"collections/"~table~"/records/"~item.id, serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);

			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, item.id);
			}
			else if(e.status == 403)
			{
				throw new NotAuthorized(table, item.id);
			}
			else if(e.status == 400)
			{
				throw new ValidationRequired(table, item.id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Deletes the provided record by id from the given table
	 *
	 * Params:
	 *   table = the table to delete the record from
	 *   id = the id of the record to delete
	 */
	public void deleteRecord(string table, string id)
	{
		try
		{
			del(pocketBaseURL~"collections/"~table~"/records/"~id);
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
	}

	/** 
	 * Deletes the provided record from the given table
	 *
	 * Params:
	 *   table = the table to delete from
	 *   record = the record of type <code>RecordType</code> to delete
	 */
	public void deleteRecord(string, RecordType)(string table, RecordType record)
	{
		idAbleCheck(record);
		deleteRecord(table, record.id);
	}

	public static void idAbleCheck(RecordType)(RecordType record)
	{
		static if(__traits(hasMember, record, "id"))
		{
			static if(__traits(isSame, typeof(record.id), string))
			{
				// Do nothing as it is a-okay
			}
			else
			{
				// Must be a string
				pragma(msg, "The `id` field of the record provided must be of type string");
				static assert(false);
			}
		}
		else
		{
			// An id field is required (TODO: ensure not a function identifier)
			pragma(msg, "The provided record must have a `id` field");
			static assert(false);
		}
	}

	// TODO: Implement the streaming functionality
	private void stream(string table)
	{
		
	}

	public static JSONValue serializeRecord(RecordType)(RecordType record)
	{
		import std.traits;
		import std.meta : AliasSeq;
		
		// Final JSON to submit
		JSONValue builtJSON;


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


			static if(__traits(isSame, mixin(structTypes[cnt]), int))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), uint))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), ulong))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), long))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), string))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), JSONValue))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), bool))
			{
				builtJSON[structNames[cnt]] = structValues[cnt];
			}
			else
			{
				debug(dbg)
				{
					pragma(msg, "Yaa");	
				}
				builtJSON[structNames[cnt]] = to!(string)(structValues[cnt]);
			}
		}


		return builtJSON;
	}

	public static fromJSON(RecordType)(JSONValue jsonIn)
	{
		RecordType record;

		import std.traits;
		import std.meta : AliasSeq;

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

			//TODO: Add all integral types
			static if(__traits(isSame, mixin(structTypes[cnt]), int))
			{
				mixin("record."~structNames[cnt]) = cast(int)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), uint))
			{
				mixin("record."~structNames[cnt]) = cast(uint)jsonIn[structNames[cnt]].integer();
			}
			else static if(__traits(isSame, mixin(structTypes[cnt]), ulong))
			{
				mixin("record."~structNames[cnt]) = cast(ulong)jsonIn[structNames[cnt]].integer();
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

public enum EnumType
{
	DOG,
	CAT
}

// Test serialization of a struct to JSON
unittest
{
	import std.algorithm.searching : canFind;
	import std.string : cmp;


	
	struct Person
	{
		public string firstname, lastname;
		public int age;
		public string[] list;
		public JSONValue extraJSON;
		public EnumType eType;
	}

	Person p1;
	p1.firstname  = "Tristan";
	p1.lastname = "Kildaire";
	p1.age = 23;
	p1.list = ["1", "2", "3"];
	p1.extraJSON = parseJSON(`{"item":1, "items":[1,2,3]}`);
	p1.eType = EnumType.CAT;

	JSONValue serialized = PocketBase.serializeRecord(p1);

	string[] keys = serialized.object().keys();
	assert(canFind(keys, "firstname") && cmp(serialized["firstname"].str(), "Tristan") == 0);
	assert(canFind(keys, "lastname") && cmp(serialized["lastname"].str(), "Kildaire") == 0);
	assert(canFind(keys, "age") && serialized["age"].integer() == 23);

	debug(dbg)
	{
		writeln(serialized.toPrettyString());
	}
}


unittest
{
	import std.string : cmp;
	
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

	Person person = PocketBase.fromJSON!(Person)(json);

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

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
	PocketBase pb = new PocketBase();

	struct Person
	{
		string id;
		string name;
		int age;
	}

	Person p1 = Person();
	p1.name = "Tristan Gonzales";
	p1.age = 23;

	Person recordStored = pb.createRecord("dummy", p1);
	pb.deleteRecord("dummy", recordStored.id);


	recordStored = pb.createRecord("dummy", p1);
	Thread.sleep(dur!("seconds")(3));
	recordStored.age = 46;
	recordStored = pb.updateRecord("dummy", recordStored);
	assert(recordStored.age == 46);
	Thread.sleep(dur!("seconds")(3));

	Person recordFetched = pb.viewRecord!(Person)("dummy", recordStored.id);
	assert(recordFetched.age == 46);
	assert(cmp(recordFetched.name, "Tristan Gonzales") == 0);
	assert(cmp(recordFetched.id, recordStored.id) == 0);

	pb.deleteRecord("dummy", recordStored);

	Person[] people = [Person(), Person()];
	people[0].name = "Abby";
	people[1].name = "Becky";

	people[0] = pb.createRecord("dummy", people[0]);
	people[1] = pb.createRecord("dummy", people[1]);

	Person[] returnedPeople = pb.listRecords!(Person)("dummy");
	foreach(Person returnedPerson; returnedPeople)
	{
		debug(dbg)
		{
			writeln(returnedPerson);
		}
		pb.deleteRecord("dummy", returnedPerson);
	}

	try
	{
		recordFetched = pb.viewRecord!(Person)("dummy", people[0].id);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}

	try
	{
		recordFetched = pb.updateRecord("dummy", people[0]);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}

	try
	{
		pb.deleteRecord("dummy", people[0]);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}
}

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
	PocketBase pb = new PocketBase();

	struct Person
	{
		string id;
		string email;
		string username;
		string password;
		string passwordConfirm;
	}

	Person p1;
	p1.email = "deavmi@redxen.eu";
	p1.username = "deavmi";
	p1.password = "bigbruh1111";
	p1.passwordConfirm = "bigbruh1111";

	p1 = pb.createRecord("dummy_auth", p1, true);
	pb.deleteRecord("dummy_auth", p1);
}

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
	PocketBase pb = new PocketBase();

	struct Person
	{
		string id;
		string name;
		int age;
	}

	Person p1 = Person();
	p1.name = "Tristan Gonzales";
	p1.age = 23;

	Person p2 = Person();
	p2.name = p1.name;
	p2.age = p1.age;

	p1 = pb.createRecord("dummy", p1);
	p2 = pb.createRecord("dummy", p2);

	Person[] people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 1);
	assert(cmp(people[0].id, p1.id) == 0);
}
