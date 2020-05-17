/// Copyright (c) 2020 George Hanna
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sub-licensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.


import FirebaseAuth
import Firebase
import FirebaseDatabase

class FirebaseManager: NSObject{
    
    private static let path: Paths = Paths()
    
    override init() {}
    
    // Sing-Up User
    static func signUpUser(user: Patient, completionHandler: @escaping ((String, Bool) -> Void)){
        Auth.auth().createUser(withEmail: user.email, password: user.password) { (result, error) in
            if error == nil {
                guard let currentUser = Auth.auth().currentUser else {return }
                currentUser.sendEmailVerification(completion: nil)
                let userId = currentUser.uid
                let changeRequest = currentUser.createProfileChangeRequest()
                changeRequest.displayName = user.fullName()
                changeRequest.commitChanges { (error) in
                    if (error != nil){
                        print(error!.localizedDescription)
                    }
                }
                Database.database().reference().child(path.patients).child(userId).child(path.info).setValue(user.dictionarize())
                completionHandler("Sign-Up Successfully. Please verify your email through the link sent to your email.", true)
            }else{
                completionHandler(error!.localizedDescription, false)
            }
        }
    }
    
    // Check if user is signned in
    static func checkSignIn() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    // Sign-in user
    static func signInUser(email: String, password: String,completionHandler: @escaping ((String, Bool) -> Void)){
        if !checkSignIn(){
            Auth.auth().signIn(withEmail: email, password: password) { (data, error) in
                if error == nil{
                    completionHandler("", true)
                }else{
                    completionHandler(error!.localizedDescription, false)
                }
            }
        }else{
            print("User already signned in...")
            completionHandler("", true)
        }
    }
    
    // Forgot password and change passowrd
    static func forgotPassword(email: String, completionHandler: @escaping ((String, Bool) -> Void)){
        Auth.auth().sendPasswordReset(withEmail: email) { (error) in
            if (error == nil){
                completionHandler("Password reset sent to email." , true)
            }else{
                completionHandler(error!.localizedDescription, false)
            }
        }
    }
    
    // Log out user
    static func logOutUser(completionHandler: () -> Void){
        do{
            try Auth.auth().signOut()
            print("User logged out successfully...")
        }catch let err{
            print(err)
        }
    }
    
    // Update display name for user in Firebase
    static func updateDisplayName(user: Patient){
        guard let currentUser = Auth.auth().currentUser else {return}
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = user.fullName()
        changeRequest.commitChanges { (error) in
            if (error != nil){
                print(error!.localizedDescription)
            }
        }
    }
    
    // Check if user's email is verified
    static func isEmailVerified() -> Bool{
        guard let emailVerified = Auth.auth().currentUser?.isEmailVerified else {return false}
        return emailVerified
    }
    
    // Add doctor to patient
    static func addDoctorToPatient(doctor: Doctor, completionHandler: (() -> (Void))? = {}){
        guard let id = Auth.auth().currentUser?.uid else {return}
        let cKey = generateKey()
        let ref = Database.database().reference().child(path.patients).child(id)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            if (snapshot.exists()){
                ref.child(path.doctors).child(doctor.id).setValue(
                    [path.cKey : cKey]
                )
                addPatientToDoctor(doctor: doctor, cKey: cKey)
                addChatKey(cKey: cKey)
            }
        })
        completionHandler!()
    }
    
    // Add patient to doctor
    static func addPatientToDoctor(doctor: Doctor, cKey: String){
        guard let id = Auth.auth().currentUser?.uid else {return}
        Database.database().reference().child(path.doctors).child(doctor.id).child(path.patients).child(id).setValue(
            [path.cKey : cKey]
        )
    }
    
    // Delete doctor from patient
    static func deleteDoctorFromPatient(doctor: Doctor, completionHandler: (() -> (Void))? = {}){
        guard let id = Auth.auth().currentUser?.uid else {return}
        deletePatientFromDoctor(doctor: doctor)
        Database.database().reference().child(path.patients).child(id).child(path.doctors).child(doctor.id).removeValue()
        completionHandler!()
    }
    
    // Delete patient from doctor
    static func deletePatientFromDoctor(doctor: Doctor){
        guard let id = Auth.auth().currentUser?.uid else {return}
        Database.database().reference().child(path.doctors).child(doctor.id).child(path.patients).child(id).removeValue()
    }
    
    // Get current user information
    static func getUserInfo(completionHandler: @escaping ((Patient) -> Void)){
        guard let id = Auth.auth().currentUser?.uid else {return}
        Database.database().reference().child(path.patients).child(id).child(path.info).observeSingleEvent(of: .value) { (snapshot) in
            if let info = snapshot.value as? [String:Any]{
                let patient = Patient(info: info)
                patient.capitalizeAll()
                completionHandler(patient)
            }
        }
    }
    
    // Get last seven senor value for patient
    static func getLastSevenSensorValue(dayTime: String, sensor: String, completionHandler: @escaping (([String], [Double]) -> Void)){
        guard let patientId = Auth.auth().currentUser?.uid else {return}
        Database.database().reference().child(path.patients).child(patientId).child(dayTime).child(sensor).observeSingleEvent(of: .value) { (snapshot) in
            var valDate: [String] = [String]()
            var valRecord: [Double] = [Double]()
            for child in snapshot.children.reversed(){
                if (valRecord.count == 7 && valDate.count == 7){
                    break
                }
                guard let snap = child as? DataSnapshot else {return}
                guard let val = snap.value as? String else {return}
                valRecord.append(Double(val)!)
                valDate.append(snap.key)
            }
            completionHandler(valDate, valRecord.reversed())
        }
    }
    
    // Get all patients that added current user
    static func getPatientDoctors(completionHandler: @escaping ((Doctor) -> Void)){
        guard let id = Auth.auth().currentUser?.uid else {return}
        Database.database().reference().child(path.patients).child(id).child(path.doctors).observeSingleEvent(of: .value) { (snapshot) in
            for child in snapshot.children{
                guard let snap = child as? DataSnapshot else {return}
                getDoctorhroughId(id: snap.key) { (doctor) in
                    completionHandler(doctor)
                }
            }
        }
    }
    
    // Get patient through his/her ID
    static func getDoctorhroughId(id: String, completionHandler: @escaping ((Doctor) -> Void)){
        Database.database().reference().child(path.doctors).child(id).child(path.info).observeSingleEvent(of: .value) { (snapshot) in
            guard let info = snapshot.value as? [String: Any] else { return }
            let doctor = Doctor(id: id, info: info)
            doctor.capitalizeAll()
            completionHandler(doctor)
        }
    }
    
    // Get all doctors
    static func getAllDoctors(completionHandler: @escaping (([Doctor]) -> Void)){
        Database.database().reference().child(path.doctors).observeSingleEvent(of: .value) { (snapshot) in
            var doctors: [Doctor] = [Doctor]()
            for child in snapshot.children{
                let snap = child as? DataSnapshot
                let doc = snap?.value as? [String:Any]
                let doctor = Doctor(id: snap!.key, info: doc?["info"] as! [String : Any])
                doctors.append(doctor)
            }
            completionHandler(doctors)
        }
    }
    
    // Get current user email
    static func getUserEmail(completionHandler: @escaping ((String) -> Void)){
        if let email = Auth.auth().currentUser?.email{
            completionHandler(email)
        }
    }
    
    // Get current user ID
    static func getUserID() -> String?{
        return Auth.auth().currentUser?.uid
    }
    
    // Get patient's notes and prescriptions
    static func getAll(what messageKind: String, completionHandler: @escaping (([Message]) -> Void)){
        guard let id = Auth.auth().currentUser?.uid else {return}
        let db = Database.database().reference()
        
        db.child(path.patients).child(id).child(messageKind).observe(.value) { (snapshot) in
            var messages: [Message] = [Message]()
            for child in snapshot.children.reversed(){
                guard let snap = child as? DataSnapshot else {return}
                guard let messageInfo = snap.value as? [String: Any] else {return}
                messages.append(Message(info: messageInfo))
            }
            completionHandler(messages)
        }
    }
    
    // Update user location
    static func updateLocation(location: String){
        guard let id = Auth.auth().currentUser?.uid else {return}
        let ref = Database.database().reference().child(path.patients).child(id)
        ref.observeSingleEvent(of: .value) { (snapshot) in
            if (snapshot.exists()){
                ref.child(path.info).child(path.location).setValue(location)
            }
        }
    }
}

// Chat Functionality
extension FirebaseManager{
    
    // Generat cKey
    private static func generateKey() -> String{
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<20).map{ _ in letters.randomElement()! })
    }
    
    // Add message to Firebase
    static func updateChatMessages(at cKey: String, with message: String){
        guard let id = Auth.auth().currentUser?.uid else {return}
        
        let currentDate = NSDate()
        let timeStamp = currentDate.timeIntervalSince1970
        let message = Message(owner: id, message: message, date: timeStamp)
        
        Database.database().reference().child(path.cKey).child(cKey).childByAutoId().setValue(
            message.dictionarizeWithId()
        )
    }
    
    // Add cKey
    static func addChatKey(cKey: String){
        Database.database().reference().child(path.cKey).child(cKey).setValue("")
    }
    
    // Listen for any changes in Firebase
    static func listenChatMessages(at cKey: String, completionHandler: @escaping (([Message]) -> Void)){
        Database.database().reference().child(path.cKey).child(cKey).observe(.value) { (snapshot) in
            var messages: [Message] = [Message]()
            for child in snapshot.children{
                guard let snap = child as? DataSnapshot else {return}
                guard let messageInfo = snap.value as? [String: Any] else {return}
                messages.append(Message(info: messageInfo))
            }
            completionHandler(messages)
        }
    }
    
    // Get chat key from Firebase
    static func getCKey(doctor: Doctor, completionHandler: @escaping ((String) -> Void)){
        guard let id = Auth.auth().currentUser?.uid else {return}
        let ref = Database.database().reference().child(path.patients).child(id)
        ref.child(path.doctors).child(doctor.id).child(path.cKey).observeSingleEvent(of: .value) { (snapshot) in
            guard let cKey = snapshot.value as? String else {return}
            completionHandler(cKey)
        }
    }
}
