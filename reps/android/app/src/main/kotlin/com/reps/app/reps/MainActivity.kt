package com.reps.app.reps

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (em vez de FlutterActivity) e obrigatorio pelo
// plugin `health`: o fluxo de permissao do Health Connect usa Activity Result
// Contracts do AndroidX, que exigem um FragmentActivity como host.
class MainActivity : FlutterFragmentActivity()
