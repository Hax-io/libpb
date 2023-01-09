Base collections
================

Below we have a few calls like create and delete:

```d
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
recordStored.age = 46;
recordStored = pb.updateRecord("dummy", recordStored);

Person recordFetched = pb.viewRecord!(Person)("dummy", recordStored.id);

pb.deleteRecord("dummy", recordStored);

Person[] people = [Person(), Person()];
people[0].name = "Abby";
people[1].name = "Becky";

people[0] = pb.createRecord("dummy", people[0]);
people[1] = pb.createRecord("dummy", people[1]);

Person[] returnedPeople = pb.listRecords!(Person)("dummy");
foreach(Person returnedPerson; returnedPeople)
{
	writeln(returnedPerson);
	pb.deleteRecord("dummy", returnedPerson);
}
```