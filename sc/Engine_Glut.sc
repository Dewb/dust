
Engine_Glut : CroneEngine {
	classvar nvoices = 4;

	var effect;
	var <buf;
	var <voices;
	var mixBus;
	var <phases;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	// disk read
	readBuf { arg i, path;
		if(buf[i].notNil, {
			var newbuf = Buffer.readChannel(context.server, path, 0, -1, [0], {
				voices[i].set(\buf, newbuf);
				buf[i].free;
				buf[i] = newbuf;
			});
		});
	}

	alloc {
		buf = Array.fill(nvoices, { arg i;
			Buffer.alloc(
				context.server,
				context.server.sampleRate * 1,
			);
		});

		SynthDef(\synth, {
			arg out, phase_out, buf, gate=0, pos=0, t_pos=0, rate=1;
			var phase;
			var phase_jitter;
			var phase_sig;
			var sig;
			var env;

			var dur = BufDur.kr(buf);

			phase_jitter = LFNoise1.kr(freq: 50, mul: 0.005);
			phase = Phasor.kr(trig: t_pos,
				rate: BufDur.kr(buf).reciprocal / ControlRate.ir * rate,
				resetPos: pos);
			phase_sig = Wrap.kr(phase + phase_jitter);

			env = EnvGen.ar(Env.adsr(), gate: gate);

			sig = GrainBuf.ar(2,
				Dust.kr(15), // trig
				0.15, //dur
				buf,
				1, // rate
				phase_sig, // pos
				2, // interp
				0, -1);
			sig = sig * env;
			Out.ar(out, sig);
			Out.kr(phase_out, phase); // or phase_sig?
		}).add;

		SynthDef(\effect, {
			arg in, out, mix=0.66, room=1.0, damp=1;
			var sig = In.ar(in, 2);
			sig = FreeVerb.ar(sig, mix, room, damp);
			Out.ar(out, sig);
		}).add;

		context.server.sync;

		// mix bus for all synth outputs
		mixBus =  Bus.audio(context.server, 2);

		effect = Synth.new(\effect, [\in, mixBus.index, \out, context.out_b.index]);

		phases = Array.fill(nvoices, { arg i;
			Bus.control(context.server);
		});

		voices = Array.fill(nvoices, { arg i;
			Synth.new(\synth, [
				\out, mixBus.index,
				\phase_out, phases[i].index,
				\buf, buf[i],
			]);
		});

		context.server.sync;

		this.addCommand("read", "is", { arg msg;
			this.readBuf(msg[1] - 1, msg[2]);
		});

		this.addCommand("pos", "if", { arg msg;
			var voice = msg[1] - 1;
			var synth = voices[voice];

			synth.set(\pos, msg[2]);
			synth.set(\t_pos, 1);
		});

		this.addCommand("gate", "ii", { arg msg;
			var voice = msg[1] - 1;
			var synth = voices[voice];

			synth.set(\gate, msg[2]);
		});

		this.addCommand("rate", "if", { arg msg;
			var voice = msg[1] - 1;
			var synth = voices[voice];

			synth.set(\rate, msg[2]);
		});

		nvoices.do({ arg i;
			this.addPoll(("phase_" ++ (i+1)).asSymbol, {
				var val = phases[i].getSynchronous;
				val
			});
		});
	}

	free {
		super.free;
	}
}
