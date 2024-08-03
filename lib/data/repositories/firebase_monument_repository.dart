import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:monumento/data/models/bookmarked_monument_model.dart';
import 'package:monumento/data/models/monument_model.dart';
import 'package:monumento/data/models/user_model.dart';
import 'package:monumento/data/models/wiki_data_model.dart';
import 'package:monumento/domain/repositories/authentication_repository.dart';
import 'package:monumento/domain/repositories/monument_repository.dart';
import 'package:wikipedia/wikipedia.dart';

class FirebaseMonumentRepository implements MonumentRepository {
  final AuthenticationRepository authenticationRepository;
  final FirebaseFirestore _database;

  FirebaseMonumentRepository(this.authenticationRepository,
      {FirebaseFirestore? database})
      : _database = database ?? FirebaseFirestore.instance;

  @override
  Future<List<MonumentModel>> getPopularMonuments() async {
    final docs = await _database.collection('monuments').get();
    final List<MonumentModel> popularMonumentsDocs =
        docs.docs.map((doc) => MonumentModel.fromJson(doc.data())).toList();
    return popularMonumentsDocs;
  }

  @override
  Future<List<MonumentModel>> getBookmarkedMonuments() async {
    try {
      var (userLoggedIn, user) = await authenticationRepository.getUser();
      if (!userLoggedIn) {
        throw Exception("User not logged in");
      }
      final snap = await _database
          .collection('bookmarks')
          .where('uid', isEqualTo: user?.uid)
          .get();
      final monumentIdsList =
          snap.docs.map((doc) => doc['monumentId']).toList();
      final List<MonumentModel> bookmarkedMonuments = [];
      for (var monumentId in monumentIdsList) {
        final monumentSnap =
            await _database.collection('monuments').doc(monumentId).get();
        if (monumentSnap.exists) {
          bookmarkedMonuments.add(MonumentModel.fromJson(monumentSnap.data()!));
        }
      }
      return bookmarkedMonuments;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<UserModel?> getProfileData(String userId) async {
    final snap = await _database.collection('users').doc(userId).get();
    if (snap.exists) {
      return UserModel.fromJson(snap.data()!);
    }
    return null;
  }

  @override
  Future<WikiDataModel> getMonumentWikiDetails(String wikiId) async {
    Wikipedia instance = Wikipedia();
    var res = await instance.searchSummaryWithPageId(pageId: int.parse(wikiId));
    return WikiDataModel(
      extract: res!.extract!,
      title: res.title!,
      description: res.description!,
      pageId: wikiId,
    );
  }

  @override
  Future<bool> bookmarkMonument(String monumentId) async {
    try {
      var (userLoggedIn, user) = await authenticationRepository.getUser();
      if (!userLoggedIn) {
        throw Exception("User not logged in");
      }
      await _database.collection('bookmarks').add({
        'uid': user?.uid,
        'monumentId': monumentId,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> unbookmarkMonument(String monumentId) async {
    try {
      var (userLoggedIn, user) = await authenticationRepository.getUser();
      if (!userLoggedIn) {
        throw Exception("User not logged in");
      }
      final snap = await _database
          .collection('bookmarks')
          .where('uid', isEqualTo: user?.uid)
          .where('monumentId', isEqualTo: monumentId)
          .get();
      if (snap.docs.isNotEmpty) {
        await _database
            .collection('bookmarks')
            .doc(snap.docs.first.id)
            .delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isMonumentBookmarked(String monumentId) async {
    try {
      var (userLoggedIn, user) = await authenticationRepository.getUser();
      if (!userLoggedIn) {
        throw Exception("User not logged in");
      }
      final snap = await _database
          .collection('bookmarks')
          .where('uid', isEqualTo: user?.uid)
          .where('monumentId', isEqualTo: monumentId)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
