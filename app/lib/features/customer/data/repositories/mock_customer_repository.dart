import 'dart:async';
import '../../../../core/repositories/i_customer_repository.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../../../../core/services/registered_worker_store.dart';
import '../models/customer_models.dart';

class MockCustomerRepository implements ICustomerRepository {
  final List<ServiceCategory> categories = const [
    ServiceCategory(id: 'c1', name: 'Electrical', iconData: 'power'),
    ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing'),
    ServiceCategory(id: 'c3', name: 'Carpentry', iconData: 'carpenter'),
    ServiceCategory(id: 'c4', name: 'Cleaning', iconData: 'cleaning_services'),
    ServiceCategory(id: 'c5', name: 'Painting', iconData: 'format_paint'),
    ServiceCategory(id: 'c6', name: 'Appliance', iconData: 'home_repair_service'),
    ServiceCategory(id: 'c7', name: 'Gardening', iconData: 'yard'),
    ServiceCategory(id: 'c8', name: 'Driver', iconData: 'directions_car'),
  ];

  List<Worker> get workers => _mockWorkers;

  static final List<Worker> _mockWorkers = [
    // 1. Registered Worker: Rahul Patil (Kothrud, Pune - Plumbing)
    const Worker(
      id: 'w101',
      name: 'Rahul Patil',
      categoryId: 'c2',
      rate: 349,
      rating: 4.88,
      reviewCount: 42,
      jobsCompleted: 126,
      distanceKm: 1.2,
      experience: '5 Years exp',
      availability: 'Available Today',
      specializations: ['Plumbing & Pipe Fitting', 'Leak Detection', 'Tap Repair'],
      locationTag: 'Kothrud, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
      customTag: 'Union Registered Artisan',
      bio: 'Certified Pune Plumbers Guild member serving Kothrud, Bavdhan, and western Pune with emergency leakage and sanitary solutions.',
      federationId: 'PUN-PLM-2023-128',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी', 'हिंदी', 'English'],
      serviceAreas: ['Kothrud', 'Bavdhan', 'Warje', 'Deccan', 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: true,
    ),
    // 2. Registered Worker: Ramesh Deshpande (Kothrud, Pune - Plumbing)
    const Worker(
      id: 'W3',
      name: 'Ramesh Deshpande',
      categoryId: 'c2',
      rate: 420,
      rating: 4.75,
      reviewCount: 120,
      jobsCompleted: 120,
      distanceKm: 1.8,
      experience: '10+ years exp',
      availability: 'Available Today',
      specializations: ['Plumber', 'Pipeline Overhaul', 'Sanitary Fittings'],
      locationTag: 'Kothrud, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCWIMvt4QiD8491szpNAgz6qtoF2oak9J_J5d572etL-J9njPqjWpNArufe8bqQKqjK0xEIUdWOMGFNyZqVx_x_pvMU-q7JpNTc-C5onCUYLkKusQO6MNINZYj_uDU-b11f1dzlB8Ja-vPD43OQdmslX0KR1K2zvWDo5_Vh0WxKjg_2he9hW-a43Dz0Hmj_nfAcyF11QkySe8GyB5BdE-Kkh2GrSYhEhqSxbfug8X2qUpNPB4si2C4_OQ',
      customTag: 'Union Master',
      bio: 'Senior union artisan certified by Pune Cooperative Federation. Experienced across residential and commercial plumbing.',
      federationId: 'MH-1122',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी', 'हिंदी'],
      serviceAreas: ['Kothrud', 'Shivajinagar', 'Deccan', 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: true,
    ),
    // 3. Registered Worker: Ganesh Shinde (Baner & Balewadi, Pune - Electrical)
    const Worker(
      id: 'W1',
      name: 'Ganesh Shinde',
      categoryId: 'c1',
      rate: 399,
      rating: 4.80,
      reviewCount: 18,
      jobsCompleted: 18,
      distanceKm: 2.4,
      experience: '5+ years exp',
      availability: 'Available Today',
      specializations: ['Electrician', 'Switchboard Repair', 'Inverter Line'],
      locationTag: 'Baner & Balewadi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDatl6mPyPeQtKgZwVVuZ8tx23q-vk1HnmX4GVP5kkw-VNTKxyzxPZb3ZLolPVk73CLbYp7zw2wHWyNliJu3z_osZRvf9hdRf3W7WYL2zn2jT0ZaTQ1k1yZfHV7eiEwlYgvwrP7K-q-q4khoqvAN4nCoGrPkX7lsLSlUv2b4W75936udvEFPFC0sxVBlNJIhRIPy7SMPR1zFyiMtONkWE_mTf1mtRZpZHpHH9doNHyzW41GswZZBNzzgw',
      customTag: 'Federation Member',
      bio: 'Pune Labour Collective electrician trained in modern electrical installations and surge protections.',
      federationId: 'MH-8219',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी', 'हिंदी'],
      serviceAreas: ['Baner', 'Balewadi', 'Aundh', 'Pashan', 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: false,
    ),
    // 4. Registered Worker: Sunita Kamble (Viman Nagar, Pune - Cleaning)
    const Worker(
      id: 'W2',
      name: 'Sunita Kamble',
      categoryId: 'c4',
      rate: 299,
      rating: 4.90,
      reviewCount: 45,
      jobsCompleted: 45,
      distanceKm: 3.1,
      experience: '3+ years exp',
      availability: 'Available Today',
      specializations: ['Deep Cleaning', 'Sanitization', 'Kitchen Cleaning'],
      locationTag: 'Viman Nagar, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAeeQvIUJTbnmWT1V9-X26KV_76HC4s7D3pGhOhAunSbsOlMlFVuMA1P7rT_n30VgpTihgoD3hPbVaOJVnzhZUOaxxROST4fZe5loh6d4vdEFJPcJxfDb7ST1ftNNlfOscwrOOf0syt0wZk8R8gRCkVV6-YCQUIFPR8py_b19g3Bt-EnYB6LvS2gBlF33pgR1HANwv-3-h48leAjyKa3XJeQnNdADYBRoCo8oCNSe3mNKjxns8qMhYlsA',
      customTag: 'Women Collective Leader',
      bio: 'Pune Women Collective sanitation specialist. Expert in home and commercial deep cleaning.',
      federationId: 'SHG-102',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी', 'हिंदी'],
      serviceAreas: ['Viman Nagar', 'Kalyani Nagar', 'Koregaon Park', 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: true,
    ),
    Worker(
      id: 'w1',
      name: 'Rameshwar Shinde',
      categoryId: 'c2',
      rate: 399,
      rating: 4.88,
      reviewCount: 184,
      jobsCompleted: 240,
      distanceKm: 1.4,
      experience: '11 yrs exp',
      availability: 'Available Today, 10:30 AM',
      specializations: ['Master Plumbing', 'Leak Detection', 'Water Heater Installation'],
      locationTag: 'Kothrud, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
      customTag: 'Pune Cooperative Certified',
      bio: 'Certified artisan registered with Pune District Cooperative Labour Federation. Specializes in leak detection, bathroom fittings, solar water connections, and emergency repairs with own calibrated toolset.',
      federationId: 'PUN-PLM-2018-88',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी (Native)', 'हिंदी', 'English'],
      serviceAreas: ['Kothrud', 'Bavdhan', 'Erandwane', 'Deccan', 'Karve Nagar'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w2',
      name: 'Sunil Deshpande',
      categoryId: 'c2',
      rate: 349,
      rating: 4.79,
      reviewCount: 142,
      jobsCompleted: 195,
      distanceKm: 2.1,
      experience: '8 Yrs Experience',
      availability: 'Available Today, 1:00 PM',
      specializations: ['Drainage Unclogging', 'Heavy Pipe Fitting', 'Pressure Pumps'],
      locationTag: 'Kothrud, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAeeQvIUJTbnmWT1V9-X26KV_76HC4s7D3pGhOhAunSbsOlMlFVuMA1P7rT_n30VgpTihgoD3hPbVaOJVnzhZUOaxxROST4fZe5loh6d4vdEFJPcJxfDb7ST1ftNNlfOscwrOOf0syt0wZk8R8gRCkVV6-YCQUIFPR8py_b19g3Bt-EnYB6LvS2gBlF33pgR1HANwv-3-h48leAjyKa3XJeQnNdADYBRoCo8oCNSe3mNKjxns8qMhYlsA',
      federationId: 'PUN-PLM-2019-044',
      serviceAreas: ['Kothrud', 'Bavdhan', 'Warje', 'Shivane'],
      isUnionGold: true,
    ),
    Worker(
      id: 'w3',
      name: 'Santosh Gaikwad',
      categoryId: 'c2',
      rate: 450,
      rating: 4.92,
      reviewCount: 310,
      jobsCompleted: 420,
      distanceKm: 3.5,
      experience: '14+ Yrs Trade Vet',
      availability: 'Available Tomorrow (Slot 1)',
      specializations: ['Commercial & Home Plumbing', 'Central Pipeline Overhaul'],
      locationTag: 'Shivajinagar, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCWIMvt4QiD8491szpNAgz6qtoF2oak9J_J5d572etL-J9njPqjWpNArufe8bqQKqjK0xEIUdWOMGFNyZqVx_x_pvMU-q7JpNTc-C5onCUYLkKusQO6MNINZYj_uDU-b11f1dzlB8Ja-vPD43OQdmslX0KR1K2zvWDo5_Vh0WxKjg_2he9hW-a43Dz0Hmj_nfAcyF11QkySe8GyB5BdE-Kkh2GrSYhEhqSxbfug8X2qUpNPB4si2C4_OQ',
      federationId: 'PUN-PLM-2016-012',
      serviceAreas: ['Shivajinagar', 'Deccan', 'Model Colony', 'FC Road'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w4',
      name: 'Amit Deshmukh',
      categoryId: 'c1',
      rate: 299,
      rating: 4.90,
      reviewCount: 214,
      jobsCompleted: 350,
      distanceKm: 2.1,
      experience: '9 yrs exp',
      availability: 'Available Today, 4:00 PM',
      specializations: ['Master Electrician', 'Wiring & Inverter', 'Circuit Diagnostics'],
      locationTag: 'Baner & Balewadi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDatl6mPyPeQtKgZwVVuZ8tx23q-vk1HnmX4GVP5kkw-VNTKxyzxPZb3ZLolPVk73CLbYp7zw2wHWyNliJu3z_osZRvf9hdRf3W7WYL2zn2jT0ZaTQ1k1yZfHV7eiEwlYgvwrP7K-q-q4khoqvAN4nCoGrPkX7lsLSlUv2b4W75936udvEFPFC0sxVBlNJIhRIPy7SMPR1zFyiMtONkWE_mTf1mtRZpZHpHH9doNHyzW41GswZZBNzzgw',
      federationId: 'PUN-ELE-2018-088',
      serviceAreas: ['Baner', 'Balewadi', 'Pashan', 'Mahalunge'],
      isUnionGold: true,
    ),
    Worker(
      id: 'w5',
      name: 'Sachin Jadhav',
      categoryId: 'c2',
      rate: 379,
      rating: 4.85,
      reviewCount: 168,
      jobsCompleted: 210,
      distanceKm: 4.2,
      experience: '10 yrs exp',
      availability: 'Available Today, 2:30 PM',
      specializations: ['Industrial & Domestic Plumbing', 'Water Purifier & RO Line', 'Tank Automation'],
      locationTag: 'Hinjewadi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
      federationId: 'PUN-PLM-2020-045',
      serviceAreas: ['Hinjewadi', 'Maan', 'Marunji', 'Wakad'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w6',
      name: 'Dnyaneshwar Pawar',
      categoryId: 'c6',
      rate: 399,
      rating: 4.87,
      reviewCount: 195,
      jobsCompleted: 280,
      distanceKm: 5.6,
      experience: '9 yrs exp',
      availability: 'Available Today, 5:00 PM',
      specializations: ['Appliance Repair', 'AC Servicing & Gas Charging', 'Refrigerator Repair'],
      locationTag: 'Hadapsar, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAeeQvIUJTbnmWT1V9-X26KV_76HC4s7D3pGhOhAunSbsOlMlFVuMA1P7rT_n30VgpTihgoD3hPbVaOJVnzhZUOaxxROST4fZe5loh6d4vdEFJPcJxfDb7ST1ftNNlfOscwrOOf0syt0wZk8R8gRCkVV6-YCQUIFPR8py_b19g3Bt-EnYB6LvS2gBlF33pgR1HANwv-3-h48leAjyKa3XJeQnNdADYBRoCo8oCNSe3mNKjxns8qMhYlsA',
      federationId: 'PUN-APP-2019-034',
      serviceAreas: ['Hadapsar', 'Magarpatta', 'Amanora', 'Fursungi'],
      isUnionGold: true,
    ),
    Worker(
      id: 'w7',
      name: 'Nitin Kadam',
      categoryId: 'c5',
      rate: 499,
      rating: 4.82,
      reviewCount: 130,
      jobsCompleted: 175,
      distanceKm: 6.1,
      experience: '10 yrs exp',
      availability: 'Available Tomorrow, 9:00 AM',
      specializations: ['Professional Painting', 'Waterproofing & Wall Putty', 'Texture Design'],
      locationTag: 'Viman Nagar & Kalyani Nagar, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCWIMvt4QiD8491szpNAgz6qtoF2oak9J_J5d572etL-J9njPqjWpNArufe8bqQKqjK0xEIUdWOMGFNyZqVx_x_pvMU-q7JpNTc-C5onCUYLkKusQO6MNINZYj_uDU-b11f1dzlB8Ja-vPD43OQdmslX0KR1K2zvWDo5_Vh0WxKjg_2he9hW-a43Dz0Hmj_nfAcyF11QkySe8GyB5BdE-Kkh2GrSYhEhqSxbfug8X2qUpNPB4si2C4_OQ',
      federationId: 'PUN-PNT-2019-067',
      serviceAreas: ['Viman Nagar', 'Kalyani Nagar', 'Koregaon Park', 'Yerwada'],
      isUnionGold: true,
    ),
    Worker(
      id: 'w8',
      name: 'Ganesh Salunkhe',
      categoryId: 'c1',
      rate: 349,
      rating: 4.89,
      reviewCount: 220,
      jobsCompleted: 310,
      distanceKm: 3.8,
      experience: '8 yrs exp',
      availability: 'Available Today, 3:00 PM',
      specializations: ['Smart Home Electricals', 'Submeter Installation', 'Emergency Short Circuit Fix'],
      locationTag: 'Wakad & Pimple Saudagar, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDatl6mPyPeQtKgZwVVuZ8tx23q-vk1HnmX4GVP5kkw-VNTKxyzxPZb3ZLolPVk73CLbYp7zw2wHWyNliJu3z_osZRvf9hdRf3W7WYL2zn2jT0ZaTQ1k1yZfHV7eiEwlYgvwrP7K-q-q4khoqvAN4nCoGrPkX7lsLSlUv2b4W75936udvEFPFC0sxVBlNJIhRIPy7SMPR1zFyiMtONkWE_mTf1mtRZpZHpHH9doNHyzW41GswZZBNzzgw',
      federationId: 'PUN-ELE-2020-119',
      serviceAreas: ['Wakad', 'Pimple Saudagar', 'Pimple Nilakh', 'Thergaon'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w9',
      name: 'Pravin Thorat',
      categoryId: 'c3',
      rate: 429,
      rating: 4.91,
      reviewCount: 178,
      jobsCompleted: 260,
      distanceKm: 3.1,
      experience: '11 yrs exp',
      availability: 'Available Tomorrow, 11:00 AM',
      specializations: ['Precision Woodwork', 'Modular Kitchen Repair', 'Door Hinges & Locksets'],
      locationTag: 'Aundh & Pashan, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
      federationId: 'PUN-CRP-2017-053',
      serviceAreas: ['Aundh', 'Pashan', 'Baner Road', 'University'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w10',
      name: 'Mahendra Jagtap',
      categoryId: 'c2',
      rate: 369,
      rating: 4.86,
      reviewCount: 160,
      jobsCompleted: 230,
      distanceKm: 4.8,
      experience: '12 yrs exp',
      availability: 'Available Today, 11:30 AM',
      specializations: ['Plumbing Overhaul', 'Overhead Tank Cleaning', 'Bathroom Fitting Replacement'],
      locationTag: 'Katraj & Dhankawadi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAeeQvIUJTbnmWT1V9-X26KV_76HC4s7D3pGhOhAunSbsOlMlFVuMA1P7rT_n30VgpTihgoD3hPbVaOJVnzhZUOaxxROST4fZe5loh6d4vdEFJPcJxfDb7ST1ftNNlfOscwrOOf0syt0wZk8R8gRCkVV6-YCQUIFPR8py_b19g3Bt-EnYB6LvS2gBlF33pgR1HANwv-3-h48leAjyKa3XJeQnNdADYBRoCo8oCNSe3mNKjxns8qMhYlsA',
      federationId: 'PUN-PLM-2016-091',
      serviceAreas: ['Katraj', 'Dhankawadi', 'Ambegaon', 'Bibwewadi'],
      isUnionGold: true,
    ),
    Worker(
      id: 'w11',
      name: 'Tukaram Mane',
      categoryId: 'c1',
      rate: 399,
      rating: 4.94,
      reviewCount: 340,
      jobsCompleted: 490,
      distanceKm: 3.9,
      experience: '15 yrs exp',
      availability: 'Available Today, 1:30 PM',
      specializations: ['Guild Master Electrician', 'Three-Phase Wiring', 'Distribution Board Repair'],
      locationTag: 'Swargate & Bibwewadi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCWIMvt4QiD8491szpNAgz6qtoF2oak9J_J5d572etL-J9njPqjWpNArufe8bqQKqjK0xEIUdWOMGFNyZqVx_x_pvMU-q7JpNTc-C5onCUYLkKusQO6MNINZYj_uDU-b11f1dzlB8Ja-vPD43OQdmslX0KR1K2zvWDo5_Vh0WxKjg_2he9hW-a43Dz0Hmj_nfAcyF11QkySe8GyB5BdE-Kkh2GrSYhEhqSxbfug8X2qUpNPB4si2C4_OQ',
      federationId: 'PUN-ELE-2015-007',
      serviceAreas: ['Swargate', 'Bibwewadi', 'Mukundnagar', 'Sahakarnagar'],
      isCoopMaster: true,
    ),
    Worker(
      id: 'w12',
      name: 'Vikram Nalawade',
      categoryId: 'c1',
      rate: 349,
      rating: 4.83,
      reviewCount: 145,
      jobsCompleted: 190,
      distanceKm: 6.8,
      experience: '7 yrs exp',
      availability: 'Available Today, 4:30 PM',
      specializations: ['Electrical Diagnostics', 'Ceiling Fan & Geyser Wiring', 'Inverter Battery Setup'],
      locationTag: 'Kharadi & Wagholi, Pune',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDatl6mPyPeQtKgZwVVuZ8tx23q-vk1HnmX4GVP5kkw-VNTKxyzxPZb3ZLolPVk73CLbYp7zw2wHWyNliJu3z_osZRvf9hdRf3W7WYL2zn2jT0ZaTQ1k1yZfHV7eiEwlYgvwrP7K-q-q4khoqvAN4nCoGrPkX7lsLSlUv2b4W75936udvEFPFC0sxVBlNJIhRIPy7SMPR1zFyiMtONkWE_mTf1mtRZpZHpHH9doNHyzW41GswZZBNzzgw',
      federationId: 'PUN-ELE-2021-144',
      serviceAreas: ['Kharadi', 'Wagholi', 'Chandan Nagar', 'Keshav Nagar'],
      isUnionGold: true,
    ),
  ];

  @override
  Future<List<ServiceCategory>> getActiveServices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return categories;
  }

  static void registerOrUpdateWorker(Worker worker) {
    final idx = _mockWorkers.indexWhere((w) => w.id == worker.id);
    if (idx != -1) {
      _mockWorkers[idx] = worker;
    } else {
      _mockWorkers.insert(0, worker);
    }
  }

  @override
  Future<List<Worker>> getAllWorkers({String? city, String? federationId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    var list = List<Worker>.from(_mockWorkers);
    if (federationId != null && federationId.isNotEmpty) {
      list = list.where((w) => w.federationId == federationId).toList();
    }
    if (city != null && city.isNotEmpty && city != 'All Areas') {
      list = list.where((w) => w.locationTag.toLowerCase().contains(city.toLowerCase()) || w.serviceAreas.any((a) => a.toLowerCase().contains(city.toLowerCase()))).toList();
    }
    return list;
  }

  @override
  Future<bool> hasWorkersInArea({String? federationId, String? district, String? city, String? pincode}) async {
    final all = List<Worker>.from(_mockWorkers)..addAll(RegisteredWorkerStore.getRegisteredWorkers());
    final fedId = federationId?.trim().toLowerCase();
    final dist = district?.trim().toLowerCase() ?? '';
    final c = city?.trim().toLowerCase() ?? '';

    for (final w in all) {
      if (fedId != null && fedId.isNotEmpty && w.federationId?.toLowerCase() == fedId) {
        return true;
      }
      final locTag = w.locationTag.toLowerCase();
      if (dist.isNotEmpty && locTag.contains(dist)) return true;
      if (c.isNotEmpty && locTag.contains(c)) return true;
      if (w.serviceAreas.any((a) => (dist.isNotEmpty && a.toLowerCase().contains(dist)) || (c.isNotEmpty && a.toLowerCase().contains(c)))) {
        return true;
      }
    }
    return false;
  }

  String _normalizeServiceId(String serviceId) {
    switch (serviceId.toLowerCase()) {
      case '11111111-1111-1111-1111-111111111111':
      case 'srv-electrician':
      case 'electrical':
      case 'electrician':
        return 'c1';
      case '22222222-2222-2222-2222-222222222222':
      case 'srv-plumbing':
      case 'plumbing':
      case 'plumber':
        return 'c2';
      case '33333333-3333-3333-3333-333333333333':
      case 'srv-carpentry':
      case 'carpentry':
      case 'carpenter':
        return 'c3';
      case '44444444-4444-4444-4444-444444444444':
      case 'srv-cleaning':
      case 'cleaning':
      case 'cleaner':
        return 'c4';
      case '55555555-5555-5555-5555-555555555555':
      case 'srv-painting':
      case 'painting':
      case 'painter':
        return 'c5';
      case '66666666-6666-6666-6666-666666666666':
      case 'srv-appliance':
      case 'appliance':
      case 'appliance repair':
        return 'c6';
      default:
        return serviceId;
    }
  }

  @override
  Future<List<Worker>> getEligibleWorkers(
    String serviceId, {
    double? customerLat,
    double? customerLng,
    String? serviceArea,
    bool isEmergency = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (serviceId.isEmpty || serviceId.toLowerCase() == 'all') {
      return List<Worker>.from(_mockWorkers);
    }

    try {
      final recommended = await DI.fairMatchService.getRecommendedWorkers(serviceId: serviceId);
      if (recommended.isNotEmpty) {
        if (serviceArea != null && serviceArea.isNotEmpty && serviceArea != 'All Areas') {
          final areaLower = serviceArea.toLowerCase().trim();
          final areaFiltered = recommended.where((r) =>
            r.worker.serviceAreas.any((a) =>
              a.toLowerCase().contains(areaLower) || a.toLowerCase().contains('all areas')
            )
          ).map((r) => r.worker).toList();
          if (areaFiltered.isNotEmpty) {
            return areaFiltered;
          }
        } else {
          return recommended.map((r) => r.worker).toList();
        }
      }
    } catch (_) {
      // Fallback to standard mock filtering
    }

    final normalized = _normalizeServiceId(serviceId);
    List<Worker> filtered = _mockWorkers.where((w) =>
      w.categoryId == serviceId ||
      w.categoryId == normalized ||
      w.specializations.any((s) => s.toLowerCase().contains(normalized.toLowerCase()))
    ).toList();

    if (serviceArea != null && serviceArea.isNotEmpty && serviceArea != 'All Areas') {
      final areaLower = serviceArea.toLowerCase().trim();
      filtered = filtered.where((w) {
        return w.serviceAreas.any((a) =>
          a.toLowerCase().contains(areaLower) || a.toLowerCase().contains('all areas')
        );
      }).toList();
      // If service area was explicitly requested and no workers match, return empty
      if (filtered.isEmpty) {
        return [];
      }
    }

    if (isEmergency) {
      final emergencyFiltered = filtered.where((w) =>
        w.availability.toLowerCase().contains('today') ||
        w.availability.toLowerCase().contains('now') ||
        w.availability.toLowerCase().contains('immediate')
      ).toList();
      if (emergencyFiltered.isNotEmpty) {
        filtered = emergencyFiltered;
      }
    }

    if (filtered.isNotEmpty) {
      return filtered;
    }

    return _mockWorkers.map((w) => Worker(
      id: w.id,
      name: w.name,
      categoryId: serviceId,
      rate: w.rate,
      rating: w.rating,
      reviewCount: w.reviewCount,
      jobsCompleted: w.jobsCompleted,
      distanceKm: w.distanceKm,
      experience: w.experience,
      availability: 'Available Today',
      specializations: w.specializations,
      locationTag: w.locationTag,
      imageUrl: w.imageUrl,
      customTag: w.customTag,
      bio: w.bio,
      federationId: w.federationId,
      insuranceAmount: w.insuranceAmount,
      languages: w.languages,
      serviceAreas: w.serviceAreas,
      isUnionGold: w.isUnionGold,
      isCoopMaster: w.isCoopMaster,
    )).toList();
  }

  @override
  Future<String?> createBooking({
    required String workerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    required double amount,
    String? addressId,
    String? notes,
    String bookingType = 'NORMAL',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final worker = workers.firstWhere((w) => w.id == workerId, orElse: () => workers.first);
    final category = categories.firstWhere((c) => c.id == serviceId, orElse: () => categories.first);

    return SharedBookingStore.instance.createBooking(
      workerId: workerId,
      serviceId: serviceId,
      serviceName: category.name,
      workerName: worker.name,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      amount: amount,
      addressId: addressId,
      notes: notes,
      bookingType: bookingType,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerBookings() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return SharedBookingStore.instance.getCustomerBookings();
  }

  @override
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return SharedBookingStore.instance.getBookingDetails(bookingId);
  }

  @override
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return SharedBookingStore.instance.cancelBooking(bookingId, reason: reason);
  }

  @override
  Future<bool> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? addressId,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return SharedBookingStore.instance.rescheduleBooking(
      bookingId,
      newDate: newDate,
      newTime: newTime,
      addressId: addressId,
      notes: notes,
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCustomerBookings() {
    return SharedBookingStore.instance.watchCustomerBookings();
  }

  @override
  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId) {
    return SharedBookingStore.instance.watchBookingDetails(bookingId);
  }
}
