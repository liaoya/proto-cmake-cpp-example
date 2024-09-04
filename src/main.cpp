#include <iostream>

// Including the generated header file from the protobuf compilation.
// Adjust the path as needed based on the actual location of "example.pb.h".
#include <example.pb.h>

int main() {
  // Create an instance of the Protobuf message "Person".
  example::Person person;

  // Set the name and ID fields of the "Person" message using
  // the generated Protobuf setter functions.
  person.set_name("John Doe");
  person.set_id(123);

  // Display the values of the name and ID fields using std::cout.
  std::cout << "Name: " << person.name() << std::endl;
  std::cout << "ID: " << person.id() << std::endl;

  // Return 0 to indicate successful program execution.
  return 0;
}
