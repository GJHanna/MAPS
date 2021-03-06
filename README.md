# MAPS

MAPS stands for "Medical Assistant Patient Support" is an application that is connected to Firebase. The purpose to help track a patient's last seven examinations. The examinations are divided into two parts an AM and PM bar charts. The examinations division is to help the doctor further understand the effectiveness of the prescription. The app allows the patient to chat, add, and remove a doctors.

# DISCLAIMER

THIS APPLICATION WAS DEVELOPED AS A PROOF OF CONCEPT. THIS APPLICATION SHOULDN’T BE USED WITHOUT MEDICAL EXPERTS’ APPROVAL.

# Features

- Adding a doctor
- Deleting a doctor
- Chatting with doctor
- View sensor values AM and PM
- User’s location
- View doctor’s notes and prescriptions

## Getting Started

1)	Create a Firebase project
2)	Change the database rules to the following:
        {
        "rules": {
            ".read": "auth != null",
            ".write": "auth != null"
         }
        }
3)	Download the GoogleService-Info.plist
4)	Add the GoogleService-Info.plist to the project and run the project

### Prerequisites

Cocapods should be installed on the development machine in order to install the following third-party libraries.

```
	'Charts'
	'Firebase/Analytics'
	'Firebase/Auth'
	'Firebase/Database'
```

## Built With

XCode Version 11.2.1 with Swift 5

## Authors

* **George Hanna** - *Initial work* - [GJHanna](https://github.com/GJHanna)


## License

This project is licensed under the Academic Public License - see the [LICENSE.md](LICENSE.md) file for details

