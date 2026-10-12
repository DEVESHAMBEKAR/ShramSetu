import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Details discovered when resolving a 6-digit Indian Postal PIN Code
class PincodeLookupResult {
  final String pincode;
  final String state;
  final String district;
  final String city;
  final List<String> areas;
  final bool isFromNetwork;

  const PincodeLookupResult({
    required this.pincode,
    required this.state,
    required this.district,
    required this.city,
    required this.areas,
    this.isFromNetwork = false,
  });

  @override
  String toString() =>
      'PincodeLookupResult(pincode: $pincode, state: $state, district: $district, city: $city, areas: ${areas.length})';
}

/// Comprehensive Geography & PIN Code Intelligence Service for India
/// Supports:
/// - 28 States & 8 Union Territories with official district rosters
/// - Sub-district/Area discovery
/// - Real-time Postal PIN Code resolution via India Post API with offline fallback
class IndiaGeographyService {
  IndiaGeographyService._();

  static final Map<String, PincodeLookupResult> _cache = {};

  /// All 28 States and 8 Union Territories mapped to their districts
  static const Map<String, List<String>> statesAndDistricts = {
    'Andaman and Nicobar Islands': ['Nicobar', 'North and Middle Andaman', 'South Andaman'],
    'Andhra Pradesh': [
      'Alluri Sitharama Raju', 'Anakapalli', 'Ananthapuramu', 'Annamayya', 'Bapatla',
      'Chittoor', 'Dr. B.R. Ambedkar Konaseema', 'East Godavari', 'Eluru', 'Guntur',
      'Kakinada', 'Krishna', 'Kurnool', 'Nandyal', 'NTR', 'Palnadu', 'Parvathipuram Manyam',
      'Prakasam', 'Sri Potti Sriramulu Nellore', 'Sri Sathya Sai', 'Srikakulam', 'Tirupati',
      'Visakhapatnam', 'Vizianagaram', 'West Godavari', 'YSR Kadapa'
    ],
    'Arunachal Pradesh': [
      'Anjaw', 'Changlang', 'Dibang Valley', 'East Kameng', 'East Siang', 'Itanagar Capital Complex',
      'Kamle', 'Kra Daadi', 'Kurung Kumey', 'Lepa Rada', 'Lohit', 'Longding', 'Lower Dibang Valley',
      'Lower Siang', 'Lower Subansiri', 'Namsai', 'Pakke Kessang', 'Papum Pare', 'Shi Yomi',
      'Siang', 'Tawang', 'Tirap', 'Upper Siang', 'Upper Subansiri', 'West Kameng', 'West Siang'
    ],
    'Assam': [
      'Baksa', 'Barpeta', 'Biswanath', 'Bongaigaon', 'Cachar', 'Charaideo', 'Chirang',
      'Darrang', 'Dhemaji', 'Dhubri', 'Dibrugarh', 'Dima Hasao', 'Goalpara', 'Golaghat',
      'Hailakandi', 'Hojai', 'Jorhat', 'Kamrup', 'Kamrup Metropolitan', 'Karbi Anglong',
      'Karimganj', 'Kokrajhar', 'Lakhimpur', 'Majuli', 'Morigaon', 'Nagaon', 'Nalbari',
      'Sivasagar', 'Sonitpur', 'South Salmara-Mankachar', 'Tinsukia', 'Udalguri', 'West Karbi Anglong'
    ],
    'Bihar': [
      'Araria', 'Arwal', 'Aurangabad', 'Banka', 'Begusarai', 'Bhagalpur', 'Bhojpur',
      'Buxar', 'Darbhanga', 'East Champaran', 'Gaya', 'Gopalganj', 'Jamui', 'Jehanabad',
      'Kaimur', 'Katihar', 'Khagaria', 'Kishanganj', 'Lakhisarai', 'Madhepura', 'Madhubani',
      'Munger', 'Muzaffarpur', 'Nalanda', 'Nawada', 'Patna', 'Purnia', 'Rohtas',
      'Saharsa', 'Samastipur', 'Saran', 'Sheikhpura', 'Sheohar', 'Sitamarhi', 'Siwan',
      'Supaul', 'Vaishali', 'West Champaran'
    ],
    'Chandigarh': ['Chandigarh'],
    'Chhattisgarh': [
      'Balod', 'Baloda Bazar', 'Balrampur', 'Bastar', 'Bemetara', 'Bijapur', 'Bilaspur',
      'Dantewada', 'Dhamtari', 'Durg', 'Gariaband', 'Gaurela-Pendra-Marwahi', 'Janjgir-Champa',
      'Jashpur', 'Kabirdham', 'Kanker', 'Khairagarh', 'Kondagaon', 'Korba', 'Koriya',
      'Mahasamund', 'Manendragarh-Chirmiri-Bharatpur', 'Mohla-Manpur-Ambagarh Chowki',
      'Mungeli', 'Narayanpur', 'Raigarh', 'Raipur', 'Rajnandgaon', 'Sakti', 'Sarangarh-Bilaigarh',
      'Sukma', 'Surajpur', 'Surguja'
    ],
    'Dadra and Nagar Haveli and Daman and Diu': ['Dadra and Nagar Haveli', 'Daman', 'Diu'],
    'Delhi': [
      'Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi',
      'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi', 'South West Delhi', 'West Delhi'
    ],
    'Goa': ['North Goa', 'South Goa'],
    'Gujarat': [
      'Ahmedabad', 'Amreli', 'Anand', 'Aravalli', 'Banaskantha', 'Bharuch', 'Bhavnagar',
      'Botad', 'Chhota Udaipur', 'Dahod', 'Dang', 'Devbhumi Dwarka', 'Gandhinagar',
      'Gir Somnath', 'Jamnagar', 'Junagadh', 'Kheda', 'Kutch', 'Mahisagar', 'Mehsana',
      'Morbi', 'Narmada', 'Navsari', 'Panchmahal', 'Patan', 'Porbandar', 'Rajkot',
      'Sabarkantha', 'Surat', 'Surendranagar', 'Tapi', 'Vadodara', 'Valsad'
    ],
    'Haryana': [
      'Ambala', 'Bhiwani', 'Charkhi Dadri', 'Faridabad', 'Fatehabad', 'Gurugram',
      'Hisar', 'Jhajjar', 'Jind', 'Kaithal', 'Karnal', 'Kurukshetra', 'Mahendragarh',
      'Nuh', 'Palwal', 'Panchkula', 'Panipat', 'Rewari', 'Rohtak', 'Sirsa', 'Sonipat', 'Yamunanagar'
    ],
    'Himachal Pradesh': [
      'Bilaspur', 'Chamba', 'Hamirpur', 'Kangra', 'Kinnaur', 'Kullu', 'Lahaul and Spiti',
      'Mandi', 'Shimla', 'Sirmaur', 'Solan', 'Una'
    ],
    'Jammu and Kashmir': [
      'Anantnag', 'Bandipora', 'Baramulla', 'Budgam', 'Doda', 'Ganderbal', 'Jammu',
      'Kathua', 'Kishtwar', 'Kulgam', 'Kupwara', 'Poonch', 'Pulwama', 'Rajouri',
      'Ramban', 'Reasi', 'Samba', 'Shopian', 'Srinagar', 'Udhampur'
    ],
    'Jharkhand': [
      'Bokaro', 'Chatra', 'Deoghar', 'Dhanbad', 'Dumka', 'East Singhbhum', 'Garhwa',
      'Giridih', 'Godda', 'Gumla', 'Hazaribagh', 'Jamtara', 'Khunti', 'Koderma',
      'Latehar', 'Lohardaga', 'Pakur', 'Palamu', 'Ramgarh', 'Ranchi', 'Sahebganj',
      'Seraikela Kharsawan', 'Simdega', 'West Singhbhum'
    ],
    'Karnataka': [
      'Bagalkot', 'Ballari', 'Belagavi', 'Bengaluru Rural', 'Bengaluru Urban', 'Bidar',
      'Chamarajanagar', 'Chikkaballapura', 'Chikkamagaluru', 'Chitradurga', 'Dakshina Kannada',
      'Davanagere', 'Dharwad', 'Gadag', 'Hassan', 'Haveri', 'Kalaburagi', 'Kodagu',
      'Kolar', 'Koppal', 'Mandya', 'Mysuru', 'Raichur', 'Ramanagara', 'Shivamogga',
      'Tumakuru', 'Udupi', 'Uttara Kannada', 'Vijayapura', 'Vijayanagara', 'Yadgir'
    ],
    'Kerala': [
      'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod', 'Kollam', 'Kottayam',
      'Kozhikode', 'Malappuram', 'Palakkad', 'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'
    ],
    'Ladakh': ['Kargil', 'Leh'],
    'Lakshadweep': ['Lakshadweep'],
    'Madhya Pradesh': [
      'Agar Malwa', 'Alirajpur', 'Anuppur', 'Ashoknagar', 'Balaghat', 'Barwani', 'Betul',
      'Bhind', 'Bhopal', 'Burhanpur', 'Chhatarpur', 'Chhindwara', 'Damoh', 'Datia',
      'Dewas', 'Dhar', 'Dindori', 'Guna', 'Gwalior', 'Harda', 'Hoshangabad', 'Indore',
      'Jabalpur', 'Jhabua', 'Katni', 'Khandwa', 'Khargone', 'Mandla', 'Mandsaur',
      'Morena', 'Narsinghpur', 'Neemuch', 'Niwari', 'Panna', 'Raisen', 'Rajgarh',
      'Ratlam', 'Rewa', 'Sagar', 'Satna', 'Sehore', 'Seoni', 'Shahdol', 'Shajapur',
      'Sheopur', 'Shivpuri', 'Sidhi', 'Singrauli', 'Tikamgarh', 'Ujjain', 'Umaria', 'Vidisha'
    ],
    'Maharashtra': [
      'Ahmednagar', 'Akola', 'Amravati', 'Beed', 'Bhandara', 'Buldhana', 'Chandrapur',
      'Chhatrapati Sambhajinagar', 'Dhule', 'Gadchiroli', 'Gondia', 'Hingoli', 'Jalgaon',
      'Jalna', 'Kolhapur', 'Latur', 'Mumbai City', 'Mumbai Suburban', 'Nagpur', 'Nanded',
      'Nandurbar', 'Nashik', 'Osmanabad', 'Palghar', 'Parbhani', 'Pune', 'Raigad',
      'Ratnagiri', 'Sangli', 'Satara', 'Sindhudurg', 'Solapur', 'Thane', 'Wardha',
      'Washim', 'Yavatmal'
    ],
    'Manipur': [
      'Bishnupur', 'Chandel', 'Churachandpur', 'Imphal East', 'Imphal West', 'Jiribam',
      'Kakching', 'Kamjong', 'Kangpokpi', 'Noney', 'Pherzawl', 'Senapati', 'Tamenglong',
      'Tengnoupal', 'Thoubal', 'Ukhrul'
    ],
    'Meghalaya': [
      'East Garo Hills', 'East Jaintia Hills', 'East Khasi Hills', 'Eastern West Khasi Hills',
      'North Garo Hills', 'Ri Bhoi', 'South Garo Hills', 'South West Garo Hills',
      'South West Khasi Hills', 'West Garo Hills', 'West Jaintia Hills', 'West Khasi Hills'
    ],
    'Mizoram': [
      'Aizawl', 'Champhai', 'Hnahthial', 'Khawzawl', 'Kolasib', 'Lawngtlai', 'Lunglei',
      'Mamit', 'Saitual', 'Serchhip', 'Siaha'
    ],
    'Nagaland': [
      'Chumoukedima', 'Dimapur', 'Kiphire', 'Kohima', 'Longleng', 'Mokokchung', 'Mon',
      'Niuland', 'Noklak', 'Peren', 'Phek', 'Shamator', 'Tseminyu', 'Tuensang', 'Wokha', 'Zunheboto'
    ],
    'Odisha': [
      'Angul', 'Balangir', 'Balasore', 'Bargarh', 'Bhadrak', 'Boudh', 'Cuttack', 'Deogarh',
      'Dhenkanal', 'Gajapati', 'Ganjam', 'Jagatsinghpur', 'Jajpur', 'Jharsuguda', 'Kalahandi',
      'Kandhamal', 'Kendrapara', 'Kendujhar', 'Khordha', 'Koraput', 'Malkangiri', 'Mayurbhanj',
      'Nabarangpur', 'Nayagarh', 'Nuapada', 'Puri', 'Rayagada', 'Sambalpur', 'Subarnapur', 'Sundargarh'
    ],
    'Puducherry': ['Karaikal', 'Mahe', 'Puducherry', 'Yanam'],
    'Punjab': [
      'Amritsar', 'Barnala', 'Bathinda', 'Faridkot', 'Fatehgarh Sahib', 'Fazilka', 'Ferozepur',
      'Gurdaspur', 'Hoshiarpur', 'Jalandhar', 'Kapurthala', 'Ludhiana', 'Malerkotla', 'Mansa',
      'Moga', 'Muktsar', 'Pathankot', 'Patiala', 'Rupnagar', 'Sahibzada Ajit Singh Nagar',
      'Sangrur', 'Shahid Bhagat Singh Nagar', 'Sri Muktsar Sahib', 'Tarn Taran'
    ],
    'Rajasthan': [
      'Ajmer', 'Alwar', 'Anupgarh', 'Balotra', 'Banswara', 'Baran', 'Barmer', 'Beawar',
      'Bharatpur', 'Bhilwara', 'Bikaner', 'Bundi', 'Chittorgarh', 'Churu', 'Dausa',
      'Deeg', 'Dholpur', 'Didwana-Kuchaman', 'Dudu', 'Dungarpur', 'Gangapur City',
      'Hanumangarh', 'Jaipur', 'Jaipur Rural', 'Jaisalmer', 'Jalore', 'Jhalawar',
      'Jhunjhunu', 'Jodhpur', 'Jodhpur Rural', 'Karauli', 'Kekri', 'Khairthal-Tijara',
      'Kota', 'Kotputli-Behror', 'Nagaur', 'Neem Ka Thana', 'Pali', 'Phalodi',
      'Pratapgarh', 'Rajsamand', 'Salumbar', 'Sanchore', 'Sawai Madhopur', 'Shahpura',
      'Sikar', 'Sirohi', 'Sri Ganganagar', 'Tonk', 'Udaipur'
    ],
    'Sikkim': ['Gangtok', 'Gyalshing', 'Mangan', 'Namchi', 'Pakyong', 'Soreng'],
    'Tamil Nadu': [
      'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore', 'Dharmapuri',
      'Dindigul', 'Erode', 'Kallakurichi', 'Kanchipuram', 'Kanyakumari', 'Karur',
      'Krishnagiri', 'Madurai', 'Mayiladuthurai', 'Nagapattinam', 'Namakkal', 'Nilgiris',
      'Perambalur', 'Pudukkottai', 'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga',
      'Tenkasi', 'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli',
      'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur', 'Vellore',
      'Viluppuram', 'Virudhunagar'
    ],
    'Telangana': [
      'Adilabad', 'Bhadradri Kothagudem', 'Hanumakonda', 'Hyderabad', 'Jagtial',
      'Jangaon', 'Jayashankar Bhupalpally', 'Jogulamba Gadwal', 'Kamareddy', 'Karimnagar',
      'Khammam', 'Kumuram Bheem Asifabad', 'Mahabubabad', 'Mahabubnagar', 'Mancherial',
      'Medak', 'Medchal-Malkajgiri', 'Mulugu', 'Nagarkurnool', 'Nalgonda', 'Narayanpet',
      'Nirmal', 'Nizamabad', 'Peddapalli', 'Rajanna Sircilla', 'Rangareddy', 'Sangareddy',
      'Siddipet', 'Suryapet', 'Vikarabad', 'Wanaparthy', 'Warangal', 'Yadadri Bhuvanagiri'
    ],
    'Tripura': ['Dhalai', 'Gomati', 'Khowai', 'North Tripura', 'Sepahijala', 'South Tripura', 'Unakoti', 'West Tripura'],
    'Uttar Pradesh': [
      'Agra', 'Aligarh', 'Ambedkar Nagar', 'Amethi', 'Amroha', 'Auraiya', 'Ayodhya',
      'Azamgarh', 'Badaun', 'Baghpat', 'Bahraich', 'Ballia', 'Balrampur', 'Banda',
      'Barabanki', 'Bareilly', 'Basti', 'Bhadohi', 'Bijnor', 'Bulandshahr', 'Chandauli',
      'Chitrakoot', 'Deoria', 'Etah', 'Etawah', 'Farrukhabad', 'Fatehpur', 'Firozabad',
      'Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur', 'Gonda', 'Gorakhpur', 'Hamirpur',
      'Hapur', 'Hardoi', 'Hathras', 'Jalaun', 'Jaunpur', 'Jhansi', 'Kannauj',
      'Kanpur Dehat', 'Kanpur Nagar', 'Kasganj', 'Kaushambi', 'Kheri', 'Kushinagar',
      'Lalitpur', 'Lucknow', 'Maharajganj', 'Mahoba', 'Mainpuri', 'Mathura', 'Mau',
      'Meerut', 'Mirzapur', 'Moradabad', 'Muzaffarnagar', 'Pilibhit', 'Pratapgarh',
      'Prayagraj', 'Raebareli', 'Rampur', 'Saharanpur', 'Sambhal', 'Sant Kabir Nagar',
      'Shahjahanpur', 'Shamli', 'Shravasti', 'Siddharthnagar', 'Sitapur', 'Sonbhadra',
      'Sultanpur', 'Unnao', 'Varanasi'
    ],
    'Uttarakhand': [
      'Almora', 'Bageshwar', 'Chamoli', 'Champawat', 'Dehradun', 'Haridwar',
      'Nainital', 'Pauri Garhwal', 'Pithoragarh', 'Rudraprayag', 'Tehri Garhwal',
      'Udham Singh Nagar', 'Uttarkashi'
    ],
    'West Bengal': [
      'Alipurduar', 'Bankura', 'Birbhum', 'Cooch Behar', 'Dakshin Dinajpur', 'Darjeeling',
      'Hooghly', 'Howrah', 'Jalpaiguri', 'Jhargram', 'Kalimpong', 'Kolkata', 'Malda',
      'Murshidabad', 'Nadia', 'North 24 Parganas', 'Paschim Bardhaman', 'Paschim Medinipur',
      'Purba Bardhaman', 'Purba Medinipur', 'Purulia', 'South 24 Parganas', 'Uttar Dinajpur'
    ],
  };

  /// Common localities and prominent areas for major districts
  static const Map<String, List<String>> popularDistrictAreas = {
    'Pune': [
      'Kothrud', 'Shivajinagar', 'Baner', 'Wakad', 'Hinjewadi', 'Hadapsar', 'Viman Nagar',
      'Aundh', 'Deccan Gymkhana', 'Pimpri', 'Chinchwad', 'Katraj', 'Kondhwa', 'Camp / Pune Cantonment',
      'Swargate', 'Kalyani Nagar', 'Magarpatta', 'Bavdhan', 'Karve Nagar', 'Warje', 'Sinhagad Road'
    ],
    'Mumbai City': [
      'Colaba', 'Fort', 'Marine Lines', 'Nariman Point', 'Churchgate', 'Byculla', 'Parel',
      'Dadar', 'Worli', 'Mahalaxmi', 'Tardeo', 'Girgaon', 'Malabar Hill'
    ],
    'Mumbai Suburban': [
      'Andheri East', 'Andheri West', 'Bandra West', 'Bandra East', 'Juhu', 'Santacruz',
      'Vile Parle', 'Borivali West', 'Borivali East', 'Kandivali', 'Malad', 'Goregaon',
      'Ghatkopar', 'Kurla', 'Powai', 'Chembur', 'Mulund', 'Bhandup', 'Vikhroli'
    ],
    'Thane': ['Thane West', 'Thane East', 'Kalyan', 'Dombivli', 'Mira Road', 'Bhayandar', 'Ulhasnagar', 'Badlapur'],
    'Nashik': ['Panchavati', 'Indira Nagar', 'Cidco', 'Gangapur Road', 'College Road', 'Satpur', 'Ambad', 'Deolali'],
    'Nagpur': ['Dharampeth', 'Sitabuldi', 'Civil Lines', 'Sadar', 'Ramdaspeth', 'Manish Nagar', 'Wardha Road', 'IT Park'],
    'Chhatrapati Sambhajinagar': ['Cidco', 'Garkheda', 'Samarth Nagar', 'Waluj', 'Railway Station Area', 'Shahgunj'],
    'New Delhi': ['Connaught Place', 'Chanakyapuri', 'Barakhamba', 'Gole Market', 'Lodi Colony', 'Jor Bagh'],
    'South Delhi': ['Hauz Khas', 'Saket', 'Greater Kailash', 'Lajpat Nagar', 'Vasant Kunj', 'Green Park', 'Malviya Nagar'],
    'Bengaluru Urban': ['Indiranagar', 'Koramangala', 'Whitefield', 'HSR Layout', 'Jayanagar', 'JP Nagar', 'Electronic City', 'Hebbal', 'Marathahalli', 'BTM Layout'],
    'Hyderabad': ['Banjara Hills', 'Jubilee Hills', 'Gachibowli', 'Hitec City', 'Madhapur', 'Kondapur', 'Secunderabad', 'Begumpet', 'Kukatpally'],
    'Chennai': ['T. Nagar', 'Anna Nagar', 'Adyar', 'Velachery', 'Mylapore', 'Alwarpet', 'Thiruvanmiyur', 'Nungambakkam', 'OMR'],
    'Kolkata': ['Park Street', 'Salt Lake', 'New Town', 'Ballygunge', 'Alipore', 'Gariahat', 'Howrah', 'Shyambazar'],
    'Ahmedabad': ['Navrangpura', 'Satellite', 'Bodakdev', 'Vastrapur', 'SG Highway', 'Prahlad Nagar', 'Maninagar'],
    'Jaipur': ['Malviya Nagar', 'Vaishali Nagar', 'C-Scheme', 'Mansarovar', 'Tonk Road', 'Raja Park', 'Civil Lines'],
    'Lucknow': ['Gomti Nagar', 'Hazratganj', 'Aliganj', 'Indira Nagar', 'Mahanagar', 'Alambagh', 'Vikas Nagar'],
  };

  /// Sorted list of all 36 States and Union Territories in India
  static List<String> get states => statesAndDistricts.keys.toList()..sort();
  static List<String> get allStates => states;

  /// Get official districts for a state (case-insensitive lookup)
  static List<String> getDistricts(String? stateName) {
    if (stateName == null || stateName.trim().isEmpty) {
      return statesAndDistricts['Maharashtra'] ?? [];
    }
    final normalized = matchState(stateName);
    if (normalized != null && statesAndDistricts.containsKey(normalized)) {
      return statesAndDistricts[normalized]!;
    }
    return statesAndDistricts['Maharashtra'] ?? [];
  }

  /// Get available areas/localities for a state and district
  static List<String> getAreasForDistrict(String? stateName, String? districtName) {
    if (districtName == null || districtName.trim().isEmpty) return [];
    
    // Check direct popular areas
    final matchedDist = matchDistrict(stateName, districtName);
    if (popularDistrictAreas.containsKey(matchedDist)) {
      return popularDistrictAreas[matchedDist]!;
    }

    // Default to main town names of the district
    return [
      matchedDist,
      '$matchedDist Central',
      '$matchedDist City',
      '$matchedDist Market Area',
      '$matchedDist Industrial Area',
      '$matchedDist Suburb',
    ];
  }

  /// Match a freeform state string to official name
  static String? matchState(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final state in statesAndDistricts.keys) {
      if (state.toLowerCase() == clean) return state;
    }
    for (final state in statesAndDistricts.keys) {
      if (state.toLowerCase().contains(clean) || clean.contains(state.toLowerCase())) {
        return state;
      }
    }
    return null;
  }

  /// Match a freeform district string to an official district in a state
  static String matchDistrict(String? stateName, String raw) {
    final clean = raw.trim().toLowerCase();
    final dList = getDistricts(stateName);
    for (final dist in dList) {
      if (dist.toLowerCase() == clean) return dist;
    }
    for (final dist in dList) {
      if (dist.toLowerCase().contains(clean) || clean.contains(dist.toLowerCase())) {
        return dist;
      }
    }
    return raw.trim();
  }

  /// Resolve a 6-digit Indian PIN Code automatically
  /// 1. Checks memory cache
  /// 2. Queries India Post API (api.postalpincode.in)
  /// 3. Falls back gracefully to offline geographic heuristics
  static Future<PincodeLookupResult?> lookupPincode(String pincode) async {
    final cleanPin = pincode.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanPin.length != 6) return null;

    if (_cache.containsKey(cleanPin)) {
      return _cache[cleanPin];
    }

    // 1. Try Live India Post API
    try {
      final uri = Uri.parse('https://api.postalpincode.in/pincode/$cleanPin');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first as Map<String, dynamic>;
          final status = first['Status'] as String?;
          final postOffices = first['PostOffice'] as List<dynamic>?;

          if (status == 'Success' && postOffices != null && postOffices.isNotEmpty) {
            final sample = postOffices.first as Map<String, dynamic>;
            final rawState = sample['State'] as String? ?? 'Maharashtra';
            final rawDistrict = sample['District'] as String? ?? 'Pune';
            final rawBlock = sample['Block'] as String? ?? sample['Division'] as String? ?? rawDistrict;

            final matchedState = matchState(rawState) ?? rawState;
            final matchedDistrict = matchDistrict(matchedState, rawDistrict);

            // Extract all post office localities
            final areas = <String>{};
            for (final po in postOffices) {
              final name = (po['Name'] as String?)?.trim();
              if (name != null && name.isNotEmpty) {
                areas.add(name);
              }
            }

            final result = PincodeLookupResult(
              pincode: cleanPin,
              state: matchedState,
              district: matchedDistrict,
              city: rawBlock,
              areas: areas.toList(),
              isFromNetwork: true,
            );

            _cache[cleanPin] = result;
            return result;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IndiaGeographyService] Postal API lookup failed/offline: $e');
      }
    }

    // 2. Offline fallback based on India Postal PIN Code prefixes
    final offlineResult = _resolveOfflinePincode(cleanPin);
    if (offlineResult != null) {
      _cache[cleanPin] = offlineResult;
    }
    return offlineResult;
  }

  /// Offline Geographic Heuristics by PIN Prefix
  static PincodeLookupResult? _resolveOfflinePincode(String pin) {
    if (pin.length != 6) return null;
    final prefix2 = int.tryParse(pin.substring(0, 2)) ?? 0;
    final prefix3 = int.tryParse(pin.substring(0, 3)) ?? 0;

    String state = 'Maharashtra';
    String district = 'Pune';
    String city = 'Pune';

    // Detailed 3-digit routing
    if (prefix3 >= 411 && prefix3 <= 412) {
      state = 'Maharashtra';
      district = 'Pune';
      city = 'Pune';
    } else if (prefix3 >= 400 && prefix3 <= 401) {
      state = 'Maharashtra';
      district = 'Mumbai Suburban';
      city = 'Mumbai';
    } else if (prefix3 == 422) {
      state = 'Maharashtra';
      district = 'Nashik';
      city = 'Nashik';
    } else if (prefix3 == 440) {
      state = 'Maharashtra';
      district = 'Nagpur';
      city = 'Nagpur';
    } else if (prefix3 == 431) {
      state = 'Maharashtra';
      district = 'Chhatrapati Sambhajinagar';
      city = 'Chhatrapati Sambhajinagar';
    } else if (prefix3 >= 560 && prefix3 <= 562) {
      state = 'Karnataka';
      district = 'Bengaluru Urban';
      city = 'Bengaluru';
    } else if (prefix3 >= 600 && prefix3 <= 603) {
      state = 'Tamil Nadu';
      district = 'Chennai';
      city = 'Chennai';
    } else if (prefix3 >= 500 && prefix3 <= 501) {
      state = 'Telangana';
      district = 'Hyderabad';
      city = 'Hyderabad';
    } else if (prefix3 >= 110 && prefix3 <= 111) {
      state = 'Delhi';
      district = 'New Delhi';
      city = 'Delhi';
    } else if (prefix3 >= 700 && prefix3 <= 701) {
      state = 'West Bengal';
      district = 'Kolkata';
      city = 'Kolkata';
    } else if (prefix3 >= 380 && prefix3 <= 382) {
      state = 'Gujarat';
      district = 'Ahmedabad';
      city = 'Ahmedabad';
    } else if (prefix3 >= 302 && prefix3 <= 303) {
      state = 'Rajasthan';
      district = 'Jaipur';
      city = 'Jaipur';
    } else if (prefix3 >= 226 && prefix3 <= 227) {
      state = 'Uttar Pradesh';
      district = 'Lucknow';
      city = 'Lucknow';
    } else if (prefix3 == 416) {
      state = 'Maharashtra';
      district = 'Kolhapur';
      city = 'Kolhapur';
    } else if (prefix3 == 413) {
      state = 'Maharashtra';
      district = 'Solapur';
      city = 'Solapur';
    } else if (prefix3 == 414) {
      state = 'Maharashtra';
      district = 'Ahmednagar';
      city = 'Ahmednagar';
    } else if (prefix3 == 415) {
      state = 'Maharashtra';
      district = 'Satara';
      city = 'Satara';
    } else if (prefix3 == 421) {
      state = 'Maharashtra';
      district = 'Thane';
      city = 'Thane';
    } else if (prefix3 == 423) {
      state = 'Maharashtra';
      district = 'Nashik';
      city = 'Malegaon';
    } else if (prefix3 == 424) {
      state = 'Maharashtra';
      district = 'Dhule';
      city = 'Dhule';
    } else if (prefix3 == 425) {
      state = 'Maharashtra';
      district = 'Jalgaon';
      city = 'Jalgaon';
    } else if (prefix3 == 441) {
      state = 'Maharashtra';
      district = 'Nagpur';
      city = 'Nagpur';
    } else if (prefix3 == 442) {
      state = 'Maharashtra';
      district = 'Wardha';
      city = 'Wardha';
    } else if (prefix3 == 443) {
      state = 'Maharashtra';
      district = 'Buldhana';
      city = 'Buldhana';
    } else if (prefix3 == 444) {
      state = 'Maharashtra';
      district = 'Akola';
      city = 'Akola';
    } else if (prefix3 == 445) {
      state = 'Maharashtra';
      district = 'Yavatmal';
      city = 'Yavatmal';
    } else {
      // 2-digit fallback
      if (prefix2 == 11) {
        state = 'Delhi';
        district = 'New Delhi';
        city = 'Delhi';
      } else if (prefix2 >= 12 && prefix2 <= 13) {
        state = 'Haryana';
        district = 'Gurugram';
        city = 'Gurugram';
      } else if (prefix2 >= 14 && prefix2 <= 16) {
        state = 'Punjab';
        district = 'Ludhiana';
        city = 'Ludhiana';
      } else if (prefix2 == 17) {
        state = 'Himachal Pradesh';
        district = 'Shimla';
        city = 'Shimla';
      } else if (prefix2 >= 18 && prefix2 <= 19) {
        state = 'Jammu and Kashmir';
        district = 'Srinagar';
        city = 'Srinagar';
      } else if (prefix2 >= 20 && prefix2 <= 28) {
        state = 'Uttar Pradesh';
        district = 'Lucknow';
        city = 'Lucknow';
      } else if (prefix2 >= 30 && prefix2 <= 34) {
        state = 'Rajasthan';
        district = 'Jaipur';
        city = 'Jaipur';
      } else if (prefix2 >= 36 && prefix2 <= 39) {
        state = 'Gujarat';
        district = 'Ahmedabad';
        city = 'Ahmedabad';
      } else if (prefix2 >= 40 && prefix2 <= 44) {
        state = 'Maharashtra';
        district = 'Maharashtra';
        city = 'Maharashtra';
      } else if (prefix2 >= 45 && prefix2 <= 49) {
        state = 'Madhya Pradesh';
        district = 'Bhopal';
        city = 'Bhopal';
      } else if (prefix2 >= 50 && prefix2 <= 53) {
        state = 'Telangana';
        district = 'Hyderabad';
        city = 'Hyderabad';
      } else if (prefix2 >= 56 && prefix2 <= 59) {
        state = 'Karnataka';
        district = 'Bengaluru Urban';
        city = 'Bengaluru';
      } else if (prefix2 >= 60 && prefix2 <= 64) {
        state = 'Tamil Nadu';
        district = 'Chennai';
        city = 'Chennai';
      } else if (prefix2 >= 67 && prefix2 <= 69) {
        state = 'Kerala';
        district = 'Thiruvananthapuram';
        city = 'Thiruvananthapuram';
      } else if (prefix2 >= 70 && prefix2 <= 74) {
        state = 'West Bengal';
        district = 'Kolkata';
        city = 'Kolkata';
      } else if (prefix2 >= 75 && prefix2 <= 77) {
        state = 'Odisha';
        district = 'Khordha';
        city = 'Bhubaneswar';
      } else if (prefix2 == 78) {
        state = 'Assam';
        district = 'Kamrup Metropolitan';
        city = 'Guwahati';
      } else if (prefix2 >= 80 && prefix2 <= 85) {
        state = 'Bihar';
        district = 'Patna';
        city = 'Patna';
      }
    }

    final areas = getAreasForDistrict(state, district);
    return PincodeLookupResult(
      pincode: pin,
      state: state,
      district: district,
      city: city,
      areas: areas,
      isFromNetwork: false,
    );
  }
}
