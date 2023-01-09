`auth` collections
==================

Auth collections require that certain calls, such as `createRecord(table, record, isAuthCollection)` have the last argument se to `true`.

```d
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

p1 = pb.createRecordAuth("dummy_auth", p1);
pb.deleteRecord("dummy_auth", p1);
```