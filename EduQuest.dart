import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduQuest',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
          bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'RobotoMono'),
        ),
      ),
      home: EduQuestScreen(),
    );
  }
}

class EduQuestScreen extends StatefulWidget {
  @override
  _EduQuestScreenState createState() => _EduQuestScreenState();
}

class _EduQuestScreenState extends State<EduQuestScreen> {
  late Web3Client ethClient;
  final String rpcUrl = "https://open-campus-codex-sepolia.drpc.org"; // EDU Chain Testnet RPC
  final String privateKey = "ea5701a4813312b25726cb549ab5674e17557099aacc948122b9dd59958273ad"; // Your private key
  final String contractAddress = "0xYOUR_NEW_DEPLOYED_ADDRESS"; // Deployed address daal do
  final int eduChainId = 656476; // EDU Chain Testnet Chain ID

  final String abi = '''[
    {"inputs":[],"stateMutability":"nonpayable","type":"constructor"},
    {"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"uint256","name":"points","type":"uint256"}],"name":"QuestCompleted","type":"event"},
    {"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"uint256","name":"points","type":"uint256"}],"name":"LeaderboardUpdated","type":"event"},
    {"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"uint256","name":"points","type":"uint256"}],"name":"PointsRedeemed","type":"event"},
    {"inputs":[{"internalType":"uint256","name":"_points","type":"uint256"}],"name":"completeQuest","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"currentMonth","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"getLeaderboard","outputs":[{"components":[{"internalType":"address","name":"user","type":"address"},{"internalType":"uint256","name":"points","type":"uint256"}],"internalType":"struct EduQuest.LeaderboardEntry[]","name":"","type":"tuple[]"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"getUserStats","outputs":[{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"redeemPoints","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"startNewMonth","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"users","outputs":[{"internalType":"uint256","name":"questPoints","type":"uint256"},{"internalType":"uint256","name":"completedQuests","type":"uint256"},{"internalType":"uint256","name":"monthlyPoints","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"leaderboard","outputs":[{"internalType":"address","name":"user","type":"address"},{"internalType":"uint256","name":"points","type":"uint256"}],"stateMutability":"view","type":"function"}
  ]''';

  late DeployedContract contract;
  int points = 0;
  int quests = 0;
  int monthlyPoints = 0;
  List<Map<String, dynamic>> leaderboard = [
    {"user": "User 1", "points": 0, "reward": "None"}
  ];
  String statusMessage = "Welcome to EduQuest!";
  TextEditingController pointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ethClient = Web3Client(rpcUrl, Client());
    contract = DeployedContract(
      ContractAbi.fromJson(abi, "EduQuest"),
      EthereumAddress.fromHex(contractAddress),
    );
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      setState(() => statusMessage = "Fetching data...");
      final statsFunc = contract.function('getUserStats');
      final leaderFunc = contract.function('getLeaderboard');

      final statsResult = await ethClient.call(contract: contract, function: statsFunc, params: []);
      final leaderResult = await ethClient.call(contract: contract, function: leaderFunc, params: []);

      setState(() {
        // Safely convert BigInt to int
        points = (statsResult[0] is BigInt) ? (statsResult[0] as BigInt).toInt() : 0;
        quests = (statsResult[1] is BigInt) ? (statsResult[1] as BigInt).toInt() : 0;
        monthlyPoints = (statsResult[2] is BigInt) ? (statsResult[2] as BigInt).toInt() : 0;

        // Parse leaderboard data
        leaderboard = (leaderResult[0] as List<dynamic>).map((entry) {
          return {
            "user": "User ${entry[0].toString().substring(2, 6)}", // Shortened address
            "points": (entry[1] is BigInt) ? (entry[1] as BigInt).toInt() : 0,
            "reward": (entry[1] is BigInt && (entry[1] as BigInt).toInt() > 50) ? "Silver Badge" : "Bronze Badge"
          };
        }).toList();

        if (leaderboard.isEmpty) {
          leaderboard = [{"user": "User 1", "points": 0, "reward": "None"}];
        }
        statusMessage = "Data fetched successfully!";
      });
    } catch (e) {
      setState(() => statusMessage = "Fetch failed: $e");
    }
  }

  Future<void> completeQuest() async {
    try {
      setState(() => statusMessage = "Completing quest...");
      final credentials = EthPrivateKey.fromHex(privateKey);
      final function = contract.function('completeQuest');
      final amount = int.parse(pointsController.text);
      final txHash = await ethClient.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [BigInt.from(amount)],
        ),
        chainId: eduChainId,
      );
      setState(() {
        statusMessage = "Quest completed! Tx: $txHash";
        // Local leaderboard update for demo
        leaderboard[0]["points"] = (leaderboard[0]["points"] as int) + amount;
        leaderboard[0]["reward"] = leaderboard[0]["points"] > 50 ? "Silver Badge" : "Bronze Badge";
      });
      await fetchData(); // Fetch real blockchain data
    } catch (e) {
      setState(() => statusMessage = "Quest failed: $e");
    }
  }

  Future<void> redeemPoints() async {
    try {
      setState(() => statusMessage = "Redeeming points...");
      final credentials = EthPrivateKey.fromHex(privateKey);
      final function = contract.function('redeemPoints');
      final amount = int.parse(pointsController.text);
      final txHash = await ethClient.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [BigInt.from(amount)],
        ),
        chainId: eduChainId,
      );
      setState(() => statusMessage = "Points redeemed! Tx: $txHash");
      await fetchData();
    } catch (e) {
      setState(() => statusMessage = "Redeem failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple[900]!, Colors.black],
          ),
        ),
        child: Column(
          children: [
            // Top Bar with Profile and Leaderboard
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Profile Section
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Text("Adventurer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 5),
                        Text("Points: $points", style: TextStyle(fontSize: 16, color: Colors.white70)),
                        Text("Quests: $quests", style: TextStyle(fontSize: 16, color: Colors.white70)),
                      ],
                    ),
                  ),
                  // Leaderboard Section
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Text("Leaderboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 5),
                        ...leaderboard.map((entry) => Row(
                          children: [
                            Icon(Icons.star, color: Colors.yellow, size: 20),
                            SizedBox(width: 5),
                            Text("${entry['user']}: ${entry['points']} (${entry['reward']})", style: TextStyle(fontSize: 14, color: Colors.white70)),
                          ],
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Demo Section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.purpleAccent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "How It Works",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 10),
                            Icon(Icons.book, color: Colors.orangeAccent, size: 50),
                            SizedBox(height: 10),
                            Text(
                              "1. Study a topic",
                              style: TextStyle(fontSize: 18, color: Colors.white70),
                            ),
                            Icon(Icons.arrow_downward, color: Colors.white, size: 30),
                            SizedBox(height: 10),
                            Icon(Icons.quiz, color: Colors.purpleAccent, size: 50),
                            SizedBox(height: 10),
                            Text(
                              "2. Take a test",
                              style: TextStyle(fontSize: 18, color: Colors.white70),
                            ),
                            Icon(Icons.arrow_downward, color: Colors.white, size: 30),
                            SizedBox(height: 10),
                            Icon(Icons.star, color: Colors.yellow, size: 50),
                            SizedBox(height: 10),
                            Text(
                              "3. Earn & Redeem Rewards!",
                              style: TextStyle(fontSize: 18, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      // Quest Input and Buttons
                      TextField(
                        controller: pointsController,
                        decoration: InputDecoration(
                          labelText: "Enter Points for Quest",
                          labelStyle: TextStyle(color: Colors.orangeAccent),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.orangeAccent, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: completeQuest,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          backgroundColor: Colors.purpleAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          shadowColor: Colors.purple.withOpacity(0.8),
                          elevation: 10,
                        ),
                        child: Text("Complete Quest", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: redeemPoints,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          shadowColor: Colors.blue.withOpacity(0.8),
                          elevation: 10,
                        ),
                        child: Text("Redeem Rewards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      SizedBox(height: 20),
                      Text(statusMessage, style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
