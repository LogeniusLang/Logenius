const fs = require("fs")
const child = require("child_process");
const args = process.argv.slice(2);

let ScriptFile = args[0];

const Wrap = async (Code) => {
    const output = await child.execSync(
        `lua.exe compiler.lua ${Code}`
    );
    console.log(output.toString());
};

const File = ScriptFile.includes(".lg") ? ScriptFile : `${ScriptFile}.lg`;
const Wrapped = Wrap(File);
