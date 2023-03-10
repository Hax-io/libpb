module libpb.driver;

import std.json;
import std.stdio;
import std.net.curl;
import std.conv : to;
import std.string : cmp;
import libpb.exceptions;
import jstruct : fromJSON, SerializationError, serializeRecord;


private mixin template AuthTokenHeader(alias http, PocketBase pbInstance)
{
	// Must be an instance of HTTP from `std.curl`
	static assert(__traits(isSame, typeof(http), HTTP));
	
	void InitializeAuthHeader()
	{
		// Check if the given PocketBase instance as an authToken
		if(pbInstance.authToken.length > 0)
		{
			// Then add the authaorization header
			http.addRequestHeader("Authorization", pbInstance.getAuthToken());
		}
	}
	
}

public class PocketBase
{
	private string pocketBaseURL;
	private string authToken;
	
	/** 
	 * Constructs a new PocketBase instance with
	 * the default settings
	 */
	this(string pocketBaseURL = "http://127.0.0.1:8090/api/", string authToken = "")
	{
		this.pocketBaseURL = pocketBaseURL;
		this.authToken = authToken;
	}

	public void setAuthToken(string authToken)
	{
		if(cmp(authToken, "") != 0)
		{
			this.authToken = authToken;	
		}
	}

	public string getAuthToken()
	{
		return this.authToken;
	}

	/** 
	 * List all of the records in the given table (base collection)
	 *
	 * Params:
	 *   table = the table to list from
	 *   page = the page to look at (default is 1)
	 *   perPage = the number of items to return per page (default is 30)
	 *   filter = the predicate to filter by
	 *
	 * Returns: A list of type <code>RecordType</code>
	 */
	public RecordType[] listRecords(RecordType)(string table, ulong page = 1, ulong perPage = 30, string filter = "")
	{
		return listRecords_internal!(RecordType)(table, page, perPage, filter, false);
	}

	/** 
	 * List all of the records in the given table (auth collection)
	 *
	 * Params:
	 *   table = the table to list from
	 *   page = the page to look at (default is 1)
	 *   perPage = the number of items to return per page (default is 30)
	 *   filter = the predicate to filter by
	 *
	 * Returns: A list of type <code>RecordType</code>
	 */
	public RecordType[] listRecordsAuth(RecordType)(string table, ulong page = 1, ulong perPage = 30, string filter = "")
	{
		return listRecords_internal!(RecordType)(table, page, perPage, filter, true);
	}

	/** 
	 * List all of the records in the given table (internals)
	 *
	 * Params:
	 *   table = the table to list from
	 *   page = the page to look at (default is 1)
	 *   perPage = the number of items to return per page (default is 30)
	 *   filter = the predicate to filter by
	 *   isAuthCollection = true if this is an auth collection, false
	 *   for base collection
	 *
	 * Returns: A list of type <code>RecordType</code>
	 */
	private RecordType[] listRecords_internal(RecordType)(string table, ulong page, ulong perPage, string filter, bool isAuthCollection)
	{
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();
				
		RecordType[] recordsOut;

		// Compute the query string
		string queryStr = "page="~to!(string)(page)~"&perPage="~to!(string)(perPage);

		// If there is a filter then perform the needed escaping
		if(cmp(filter, "") != 0)
		{
			// For the filter, make sure to add URL escaping to the `filter` parameter
			import etc.c.curl : curl_escape;
			import std.string : toStringz, fromStringz;
			char* escapedParameter = curl_escape(toStringz(filter), cast(int)filter.length);
			if(escapedParameter is null)
			{
				debug(dbg)
				{
					writeln("Invalid return from curl_easy_escape");
				}
				throw new NetworkException();
			}

			// Convert back to D-string (the filter)
			filter = cast(string)fromStringz(escapedParameter);
		}

		// Append the filter
		queryStr ~= cmp(filter, "") == 0 ? "" : "&filter="~filter;
		
		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records?"~queryStr, httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			JSONValue[] returnedItems = responseJSON["items"].array();

			foreach(JSONValue returnedItem; returnedItems)
			{
				// If this is an authable record (meaning it has email, password and passwordConfirm)
				// well then the latter two will not be returned so fill them in. Secondly, the email
				// will only be returned if `emailVisibility` is true.
				if(isAuthCollection)
				{
					returnedItem["password"] = "";
					returnedItem["passwordConfirm"] = "";

					// If email is invisible make a fake field to prevent crash
					if(!returnedItem["emailVisibility"].boolean())
					{
						returnedItem["email"] = "";
					}
				}
			
				recordsOut ~= fromJSON!(RecordType)(returnedItem);
			}
			
			return recordsOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 403)
			{
				throw new NotAuthorized(table, null);
			}
			else
			{
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			debug(dbg)
			{
				writeln("curl");
				writeln(e);
			}
			
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
		catch(SerializationError e)
		{
			throw new RemoteFieldMissing();
		}
	}

	/** 
	 * Creates a record in the given authentication table
	 *
	 * Params:
	 *   table = the table to create the record in
	 *   item = The Record to create
	 *
	 * Returns: An instance of the created <code>RecordType</code>
	 */
	public RecordType createRecordAuth(string, RecordType)(string table, RecordType item)
	{
		mixin isAuthable!(RecordType);

		return createRecord_internal(table, item, true);
	}

	/** 
	 * Creates a record in the given base table
	 *
	 * Params:
	 *   table = the table to create the record in
	 *   item = The Record to create
	 *
	 * Returns: An instance of the created <code>RecordType</code>
	 */
	public RecordType createRecord(string, RecordType)(string table, RecordType item)
	{
		return createRecord_internal(table, item, false);
	}

	/** 
	 * Creates a record in the given table (internal method)
	 *
	 * Params:
	 *   table = the table to create the record in
	 *   item = The Record to create
	 *   isAuthCollection = whether or not this collection is auth or not (base)
	 *
	 * Returns: An instance of the created <code>RecordType</code>
	 */
	private RecordType createRecord_internal(string, RecordType)(string table, RecordType item, bool isAuthCollection)
	{
		idAbleCheck(item);

		RecordType recordOut;
		
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		// Set the content type
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
			debug(dbg)
			{
				writeln("createRecord_internal: "~e.toString());
			}

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
		catch(SerializationError e)
		{
			throw new RemoteFieldMissing();
		}
	}

	/** 
	 * Authenticates on the given auth table with the provided
	 * credentials, returning a JWT token in the reference parameter.
	 * Finally returning the record of the authenticated user.
	 *
	 * Params:
	 *   table = the auth collection to use
	 *   identity = the user's identity
	 *   password = the user's password
	 *   token = the variable to return into
	 *
	 * Returns: An instance of `RecordType`
	 */
	public RecordType authWithPassword(RecordType)(string table, string identity, string password, ref string token)
	{
		mixin isAuthable!(RecordType);

		RecordType recordOut;

		// Set the content type
		HTTP httpSettings = HTTP();
		httpSettings.addRequestHeader("Content-Type", "application/json");

		// Construct the authentication record
		JSONValue authRecord;
		authRecord["identity"] = identity;
		authRecord["password"] = password;

		try
		{
			string responseData = cast(string)post(pocketBaseURL~"collections/"~table~"/auth-with-password", authRecord.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			JSONValue recordResponse = responseJSON["record"];

			// In the case we are doing auth, we won't get password, passwordConfirm sent back
			// set them to empty
			recordResponse["password"] = "";
			recordResponse["passwordConfirm"] = "";

			// If email is invisible make a fake field to prevent crash
			if(!recordResponse["emailVisibility"].boolean())
			{
				recordResponse["email"] = "";
			}

			recordOut = fromJSON!(RecordType)(recordResponse);

			// Store the token
			token = responseJSON["token"].str();
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 400)
			{
				// TODO: Update this error
				throw new NotAuthorized(table, null);
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
		catch(SerializationError e)
		{
			throw new RemoteFieldMissing();
		}
	}

	/** 
	 * View the given record by id (base collections)
	 *
	 * Params:
	 *   table = the table to lookup the record in
	 *   id = the id to lookup the record by
	 *
	 * Returns: The found record of type <code>RecordType</code>
	 */
	public RecordType viewRecord(RecordType)(string table, string id)
	{
		return viewRecord_internal!(RecordType)(table, id, false);
	}


	/** 
	 * View the given record by id (auth collections)
	 *
	 * Params:
	 *   table = the table to lookup the record in
	 *   id = the id to lookup the record by
	 *
	 * Returns: The found record of type <code>RecordType</code>
	 */
	public RecordType viewRecordAuth(RecordType)(string table, string id)
	{
		return viewRecord_internal!(RecordType)(table, id, true);
	}

	/** 
	 * View the given record by id (internal)
	 *
	 * Params:
	 *   table = the table to lookup the record in
	 *   id = the id to lookup the record by
	 *   isAuthCollection = true if this is an auth collection, false
	 *   for base collection
	 *
	 * Returns: The found record of type <code>RecordType</code>
	 */
	private RecordType viewRecord_internal(RecordType)(string table, string id, bool isAuthCollection)
	{
		RecordType recordOut;

		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records/"~id, httpSettings);
			JSONValue responseJSON = parseJSON(responseData);

			// If this is an authable record (meaning it has email, password and passwordConfirm)
			// well then the latter two will not be returned so fill them in. Secondly, the email
			// will only be returned if `emailVisibility` is true.
			if(isAuthCollection)
			{
				responseJSON["password"] = "";
				responseJSON["passwordConfirm"] = "";

				// If email is invisible make a fake field to prevent crash
				if(!responseJSON["emailVisibility"].boolean())
				{
					responseJSON["email"] = "";
				}
			}

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
		catch(SerializationError e)
		{
			throw new RemoteFieldMissing();
		}
	}

	/** 
	 * Updates the given record in the given table, returning the
	 * updated record (auth collections)
	 *
	 * Params:
	 *   table = tabe table to update the record in
	 *   item = the record of type <code>RecordType</code> to update
	 *
	 * Returns: The updated <code>RecordType</code>
	 */
	public RecordType updateRecordAuth(string, RecordType)(string table, RecordType item)
	{
		return updateRecord_internal(table, item, true);
	}

	/** 
	 * Updates the given record in the given table, returning the
	 * updated record (base collections)
	 *
	 * Params:
	 *   table = tabe table to update the record in
	 *   item = the record of type <code>RecordType</code> to update
	 *
	 * Returns: The updated <code>RecordType</code>
	 */
	public RecordType updateRecord(string, RecordType)(string table, RecordType item)
	{
		return updateRecord_internal(table, item, false);
	}

	/** 
	 * Updates the given record in the given table, returning the
	 * updated record (internal)
	 *
	 * Params:
	 *   table = tabe table to update the record in
	 *   item = the record of type <code>RecordType</code> to update
	 *   isAuthCollection = true if this is an auth collection, false
	 *   for base collection
	 *
	 * Returns: The updated <code>RecordType</code>
	 */
	private RecordType updateRecord_internal(string, RecordType)(string table, RecordType item, bool isAuthCollection)
	{
		idAbleCheck(item);

		RecordType recordOut;

		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		// Set the content type
		httpSettings.addRequestHeader("Content-Type", "application/json");

		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)patch(pocketBaseURL~"collections/"~table~"/records/"~item.id, serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);

			// If this is an authable record (meaning it has email, password and passwordConfirm)
			// well then the latter two will not be returned so fill them in. Secondly, the email
			// will only be returned if `emailVisibility` is true.
			if(isAuthCollection)
			{
				responseJSON["password"] = "";
				responseJSON["passwordConfirm"] = "";

				// If email is invisible make a fake field to prevent crash
				if(!responseJSON["emailVisibility"].boolean())
				{
					responseJSON["email"] = "";
				}
			}

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
		catch(SerializationError e)
		{
			throw new RemoteFieldMissing();
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
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();
		
		try
		{
			del(pocketBaseURL~"collections/"~table~"/records/"~id, httpSettings);
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

	private mixin template MemberAndType(alias record, alias typeEnforce, string memberName)
	{
		static if(__traits(hasMember, record, memberName))
		{
			static if(__traits(isSame, typeof(mixin("record."~memberName)), typeEnforce))
			{

			}
			else
			{
				pragma(msg, "Member '"~memberName~"' not of type '"~typeEnforce~"'");
				static assert(false);
			}
		}
		else
		{
			pragma(msg, "Record does not have member '"~memberName~"'");
			static assert(false);
		}
	}

	private static void isAuthable(RecordType)(RecordType record)
	{
		mixin MemberAndType!(record, string, "email");
		mixin MemberAndType!(record, string, "password");
		mixin MemberAndType!(record, string, "passwordConfirm");
	}

	private static void idAbleCheck(RecordType)(RecordType record)
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
		string name;
		int age;
	}

	// Set the password to use
	string passwordToUse = "bigbruh1111";

	Person p1;
	p1.email = "deavmi@redxen.eu";
	p1.username = "deavmi";
	p1.password = passwordToUse;
	p1.passwordConfirm = passwordToUse;
	p1.name = "Tristaniha";
	p1.age = 29;

	p1 = pb.createRecordAuth("dummy_auth", p1);


	Person[] people = pb.listRecordsAuth!(Person)("dummy_auth", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 1);

	// Ensure we get our person back
	assert(cmp(people[0].name, p1.name) == 0);
	assert(people[0].age == p1.age);
	// assert(cmp(people[0].email, p1.email) == 0);


	Person person = pb.viewRecordAuth!(Person)("dummy_auth", p1.id);

	// Ensure we get our person back
	assert(cmp(people[0].name, p1.name) == 0);
	assert(people[0].age == p1.age);
	// assert(cmp(people[0].email, p1.email) == 0);


	string newName = "Bababooey";
	person.name = newName;
	person = pb.updateRecordAuth("dummy_auth", person);
	assert(cmp(person.name, newName) == 0);



	string tokenIn;
	Person authPerson = pb.authWithPassword!(Person)("dummy_auth", p1.username, passwordToUse, tokenIn);

	// Ensure a non-empty token
	assert(cmp(tokenIn, "") != 0);
	writeln("Token: "~tokenIn);

	// Ensure we get our person back
	assert(cmp(authPerson.name, person.name) == 0);
	assert(authPerson.age == person.age);
	assert(cmp(authPerson.email, person.email) == 0);

	// Delete the record
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
	p2.name = p1.name~"2";
	p2.age = p1.age;

	p1 = pb.createRecord("dummy", p1);
	p2 = pb.createRecord("dummy", p2);

	Person[] people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 1);
	assert(cmp(people[0].id, p1.id) == 0);

	pb.deleteRecord("dummy", p1);
	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 0);

	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p2.id~"' && age=24)");
	assert(people.length == 0);

	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p2.id~"' && age=23)");
	assert(people.length == 1 && cmp(people[0].id, p2.id) == 0);
	
	pb.deleteRecord("dummy", p2);
}