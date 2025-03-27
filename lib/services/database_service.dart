import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  DatabaseService({required this.uid});

  // Collection references
  CollectionReference get userCollection => _firestore.collection('users');
  CollectionReference get jobsCollection =>
      userCollection.doc(uid).collection('jobs');
  CollectionReference get timeEntriesCollection =>
      userCollection.doc(uid).collection('timeEntries');

  // Save jobs to Firestore
  Future<void> saveJobs(List<Job> jobs) async {
    // Delete all existing jobs first
    final snapshot = await jobsCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Add all jobs
    for (var job in jobs) {
      await jobsCollection.doc(job.id).set({
        'name': job.name,
        'color': job.color.value,
        'id': job.id,
      });
    }
  }

  // Save time entries to Firestore
  Future<void> saveTimeEntries(List<TimeEntry> entries) async {
    // Delete all existing entries first
    final snapshot = await timeEntriesCollection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Add all entries
    for (var entry in entries) {
      await timeEntriesCollection.doc(entry.id).set({
        'id': entry.id,
        'jobId': entry.jobId,
        'jobName': entry.jobName,
        'jobColor': entry.jobColor.value,
        'clockInTime': entry.clockInTime.toIso8601String(),
        'clockOutTime': entry.clockOutTime.toIso8601String(),
        'duration': entry.duration.inMinutes,
        'description': entry.description,
      });
    }
  }

  // Load jobs from Firestore
  Future<List<Job>> loadJobs() async {
    try {
      final snapshot = await jobsCollection.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        // Make sure color is properly converted from int to Color
        final colorValue =
            data?['color'] is int
                ? data!['color']
                : Colors.blue.value; // Default color if missing

        return Job(
          id: doc.id,
          name: data?['name'] ?? 'Unnamed Job',
          color: Color(colorValue),
          creatorId: data?['creatorId'],
          connectionCode: data?['connectionCode'],
          isShared: data?['isShared'] ?? false,
          isPublic: data?['isPublic'] ?? true,
        );
      }).toList();
    } catch (e) {
      print('Error loading jobs: $e');
      return [];
    }
  }

  // Load time entries from Firestore
  Future<List<TimeEntry>> loadTimeEntries() async {
    final snapshot = await timeEntriesCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return TimeEntry(
        id: data['id'],
        jobId: data['jobId'],
        jobName: data['jobName'],
        jobColor: ui.Color(data['jobColor']),
        clockInTime: DateTime.parse(data['clockInTime']),
        clockOutTime: DateTime.parse(data['clockOutTime']),
        duration: Duration(minutes: data['duration']),
        description: data['description'],
      );
    }).toList();
  }

  // Add this method to check if the user is authenticated
  bool isUserAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Update the saveUserSettings method
  Future<void> saveUserSettings({
    required String languageCode,
    required String countryCode,
    required bool use24HourFormat,
    required int targetHours,
    required String themeMode,
  }) async {
    if (!isUserAuthenticated()) {
      print('Cannot save settings: User not authenticated');
      return;
    }

    try {
      await userCollection.doc(uid).update({
        'settings': {
          'languageCode': languageCode,
          'countryCode': countryCode,
          'use24HourFormat': use24HourFormat,
          'targetHours': targetHours,
          'themeMode': themeMode,
        },
      });
    } catch (e) {
      print('Error saving user settings: $e');

      // If the document doesn't exist yet, create it
      if (e.toString().contains('not-found')) {
        await userCollection.doc(uid).set({
          'settings': {
            'languageCode': languageCode,
            'countryCode': countryCode,
            'use24HourFormat': use24HourFormat,
            'targetHours': targetHours,
            'themeMode': themeMode,
          },
        });
      } else {
        rethrow;
      }
    }
  }

  // Load user settings
  Future<Map<String, dynamic>?> loadUserSettings() async {
    final doc = await userCollection.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('settings')) {
        return data['settings'];
      }
    }
    return null;
  }

  // Add this method to your DatabaseService class
  Future<void> saveTimeEntry(TimeEntry entry) async {
    try {
      // Save the time entry to the user's collection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('timeEntries')
          .doc(entry.id)
          .set(entry.toJson());

      // Check if this is for a shared job
      final jobDoc = await jobsCollection.doc(entry.jobId).get();
      if (jobDoc.exists) {
        final jobData = jobDoc.data() as Map<String, dynamic>?;
        final isShared = jobData?['isShared'] ?? false;

        if (isShared) {
          final connectionCode = jobData?['connectionCode'];
          if (connectionCode != null) {
            // Add the userId to the entry for shared jobs
            final sharedEntry = entry.toJson();
            sharedEntry['userId'] = uid;

            // Also save to a global collection for shared jobs
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .collection('timeEntries')
                .doc(entry.id)
                .set(sharedEntry);

            print('Time entry saved to shared job: ${entry.id}');
          }
        }
      }
    } catch (e) {
      print('Error saving time entry: $e');
      rethrow;
    }
  }

  // Add this method to the DatabaseService class
  Future<void> updateUserBreakState(
    bool isOnBreak,
    DateTime? breakStartTime,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnBreak': isOnBreak,
        'breakStartTime': breakStartTime?.toIso8601String() ?? '',
      });
    } catch (e) {
      print('Error updating break state: $e');
    }
  }

  // Add methods to handle shared jobs
  Future<void> createSharedJob(Job job) async {
    try {
      // Save the job to the creator's jobs collection
      await jobsCollection.doc(job.id).set({
        'id': job.id,
        'name': job.name,
        'color': job.color.value,
        'creatorId': uid,
        'connectionCode': job.connectionCode,
        'isShared': true,
        'connectedUsers': [uid],
        'isPublic': job.isPublic,
      });

      // Also add to a global shared jobs collection for lookup by code
      await _firestore.collection('sharedJobs').doc(job.connectionCode).set({
        'jobId': job.id,
        'creatorId': uid,
        'name': job.name,
        'color': job.color.value,
        'connectionCode': job.connectionCode,
        'connectedUsers': [uid],
        'isPublic': job.isPublic,
      });

      print('Shared job created successfully with isPublic=${job.isPublic}');
    } catch (e) {
      print('Error creating shared job: $e');
      throw e;
    }
  }

  Future<Job?> joinJobByCode(String connectionCode) async {
    try {
      // Look up the job in the shared jobs collection
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();

      if (!sharedJobDoc.exists) {
        throw Exception('Invalid connection code');
      }

      final sharedJobData = sharedJobDoc.data()!;
      final jobId = sharedJobData['jobId'];
      final creatorId = sharedJobData['creatorId'];
      final isPublic = sharedJobData['isPublic'] ?? true;

      print(
        'Joining job: isPublic=$isPublic, creatorId=$creatorId, currentUser=$uid',
      );

      // If the job is private and the user is not the creator
      if (!isPublic && creatorId != uid) {
        print('Creating join request for private job');
        // Create a join request instead of joining directly
        await _firestore.collection('joinRequests').add({
          'jobId': jobId,
          'connectionCode': connectionCode,
          'requesterId': uid,
          'creatorId': creatorId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
          'jobName': sharedJobData['name'],
        });

        throw Exception(
          'This job is private. A join request has been sent to the creator.',
        );
      }

      // For public jobs or if the user is the creator, proceed as normal
      final job = Job(
        id: jobId,
        name: sharedJobData['name'],
        color: ui.Color(
          sharedJobData['color'] is int
              ? sharedJobData['color']
              : Colors.blue.value,
        ),
        creatorId: creatorId,
        connectionCode: connectionCode,
        isShared: true,
        isPublic: isPublic,
      );

      // Add this job to the user's jobs collection
      await jobsCollection.doc(job.id).set(job.toJson());

      // Update the shared job's connected users list
      List<String> connectedUsers = List<String>.from(
        sharedJobData['connectedUsers'] ?? [],
      );
      if (!connectedUsers.contains(uid)) {
        connectedUsers.add(uid);
        await _firestore.collection('sharedJobs').doc(connectionCode).update({
          'connectedUsers': connectedUsers,
        });
      }

      return job;
    } catch (e) {
      print('Error joining job: $e');
      throw e;
    }
  }

  // Get all time entries for a shared job
  Future<List<TimeEntry>> getSharedJobTimeEntries(String jobId) async {
    try {
      // Get the job to check if it's shared
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      if (!(jobData?['isShared'] ?? false)) {
        throw Exception('This is not a shared job');
      }

      final connectionCode = jobData?['connectionCode'];
      if (connectionCode == null) {
        throw Exception('Invalid connection code');
      }

      // Try to get entries from the shared collection first
      final sharedEntriesSnapshot =
          await _firestore
              .collection('sharedJobs')
              .doc(connectionCode)
              .collection('timeEntries')
              .get();

      if (sharedEntriesSnapshot.docs.isNotEmpty) {
        // Use the shared entries if available
        return sharedEntriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return TimeEntry(
            id: data['id'],
            jobId: data['jobId'],
            jobName: data['jobName'],
            jobColor: ui.Color(data['jobColor']),
            clockInTime: DateTime.parse(data['clockInTime']),
            clockOutTime: DateTime.parse(data['clockOutTime']),
            duration: Duration(minutes: data['duration']),
            description: data['description'],
            userId: data['userId'],
          );
        }).toList();
      }

      // Fallback to the old method if no shared entries found
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();
      final connectedUsers = List<String>.from(
        sharedJobDoc.data()?['connectedUsers'] ?? [],
      );

      List<TimeEntry> allEntries = [];

      // Fetch time entries from all connected users
      for (String userId in connectedUsers) {
        final userEntriesSnapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('timeEntries')
                .where('jobId', isEqualTo: jobId)
                .get();

        final userEntries =
            userEntriesSnapshot.docs.map((doc) {
              final data = doc.data();
              return TimeEntry(
                id: data['id'],
                jobId: data['jobId'],
                jobName: data['jobName'],
                jobColor: ui.Color(data['jobColor']),
                clockInTime: DateTime.parse(data['clockInTime']),
                clockOutTime: DateTime.parse(data['clockOutTime']),
                duration: Duration(minutes: data['duration']),
                description: data['description'],
                userId: userId,
              );
            }).toList();

        allEntries.addAll(userEntries);
      }

      // Sort by date, newest first
      allEntries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

      return allEntries;
    } catch (e) {
      print('Error getting shared job time entries: $e');
      throw e;
    }
  }

  // Add a method to handle join requests
  Future<void> requestJobAccess(String jobId, String connectionCode) async {
    try {
      // Get the job creator
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();
      if (!sharedJobDoc.exists) {
        throw Exception('Job not found');
      }

      final creatorId = sharedJobDoc.data()?['creatorId'];

      // Create a join request
      await _firestore.collection('joinRequests').add({
        'jobId': jobId,
        'connectionCode': connectionCode,
        'requesterId': uid,
        'creatorId': creatorId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error requesting job access: $e');
      throw e;
    }
  }

  // Add a method to get pending join requests for a user
  Future<List<Map<String, dynamic>>> getPendingJoinRequests() async {
    try {
      final requestsSnapshot =
          await _firestore
              .collection('joinRequests')
              .where('creatorId', isEqualTo: uid)
              .where('status', isEqualTo: 'pending')
              .get();

      return requestsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Add the document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error getting join requests: $e');
      throw e;
    }
  }

  // Add a method to approve or deny a join request
  Future<void> respondToJoinRequest(String requestId, bool approve) async {
    try {
      // Add more detailed logging
      print('Responding to join request: $requestId, approve: $approve');

      final requestDoc =
          await _firestore.collection('joinRequests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      print('Request data: $requestData');

      // Update the request status
      await _firestore.collection('joinRequests').doc(requestId).update({
        'status': approve ? 'approved' : 'denied',
      });

      if (approve) {
        // Get the job data
        final sharedJobDoc =
            await _firestore
                .collection('sharedJobs')
                .doc(requestData['connectionCode'])
                .get();
        final sharedJobData = sharedJobDoc.data()!;

        // Create a job for the requester
        final job = Job(
          id: requestData['jobId'],
          name: sharedJobData['name'],
          color: ui.Color(
            sharedJobData['color'] is int
                ? sharedJobData['color']
                : Colors.blue.value,
          ),
          creatorId: sharedJobData['creatorId'],
          connectionCode: requestData['connectionCode'],
          isShared: true,
          isPublic: sharedJobData['isPublic'] ?? true,
        );

        // Add the job to the requester's jobs collection
        await _firestore
            .collection('users')
            .doc(requestData['requesterId'])
            .collection('jobs')
            .doc(job.id)
            .set(job.toJson());

        // Update the shared job's connected users list
        List<String> connectedUsers = List<String>.from(
          sharedJobData['connectedUsers'] ?? [],
        );
        if (!connectedUsers.contains(requestData['requesterId'])) {
          connectedUsers.add(requestData['requesterId']);
          await _firestore
              .collection('sharedJobs')
              .doc(requestData['connectionCode'])
              .update({'connectedUsers': connectedUsers});
        }
      }
    } catch (e) {
      print('Error responding to join request (detailed): $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permission denied. Please check Firestore security rules.',
        );
      }
      throw e;
    }
  }

  // Add this method to the DatabaseService class
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return {'name': 'Unknown User'}; // Return a fallback value
    }
  }

  // Add this method to delete a shared job
  Future<void> deleteSharedJob(String jobId, String connectionCode) async {
    try {
      // First, verify that the current user is the creator
      final sharedJobDoc =
          await _firestore.collection('sharedJobs').doc(connectionCode).get();

      if (!sharedJobDoc.exists) {
        throw Exception('Job not found');
      }

      final creatorId = sharedJobDoc.data()?['creatorId'];

      if (creatorId != uid) {
        throw Exception('Only the creator can delete this job');
      }

      print('Deleting shared job: $jobId with code $connectionCode');

      // Get all connected users
      final connectedUsers = List<String>.from(
        sharedJobDoc.data()?['connectedUsers'] ?? [],
      );

      // Delete the job from each connected user's collection
      for (String userId in connectedUsers) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('jobs')
            .doc(jobId)
            .delete();

        print('Deleted job from user $userId');
      }

      // Delete the shared job document
      await _firestore.collection('sharedJobs').doc(connectionCode).delete();

      // Delete any pending join requests for this job
      final requestsSnapshot =
          await _firestore
              .collection('joinRequests')
              .where('jobId', isEqualTo: jobId)
              .get();

      for (var doc in requestsSnapshot.docs) {
        await doc.reference.delete();
      }

      print('Shared job deleted successfully');
    } catch (e) {
      print('Error deleting shared job: $e');
      throw e;
    }
  }

  // Add this method to handle job deletion
  Future<void> deleteJob(String jobId) async {
    try {
      // First check if this is a shared job
      final jobDoc = await jobsCollection.doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final isShared = jobData?['isShared'] ?? false;

      if (isShared) {
        final connectionCode = jobData?['connectionCode'];
        if (connectionCode != null) {
          // This is a shared job, so we need to remove the user from the connected users list
          final sharedJobDoc =
              await _firestore
                  .collection('sharedJobs')
                  .doc(connectionCode)
                  .get();

          if (sharedJobDoc.exists) {
            List<String> connectedUsers = List<String>.from(
              sharedJobDoc.data()?['connectedUsers'] ?? [],
            );

            // Remove this user from the list
            connectedUsers.removeWhere((userId) => userId == uid);

            // Update the shared job document
            await _firestore
                .collection('sharedJobs')
                .doc(connectionCode)
                .update({'connectedUsers': connectedUsers});

            print('User removed from shared job connected users');
          }
        }
      }

      // Now delete the job from the user's collection
      await jobsCollection.doc(jobId).delete();

      print('Job deleted successfully');
    } catch (e) {
      print('Error deleting job: $e');
      throw e;
    }
  }
}
