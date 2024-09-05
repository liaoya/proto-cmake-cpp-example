#include <iostream>

#include <example.pb.h>

int main() {
  example::Person person;

  person.set_name("John Doe");
  person.set_id(123);

  std::cout << "Name: " << person.name() << std::endl;
  std::cout << "ID: " << person.id() << std::endl;

  return 0;
}
