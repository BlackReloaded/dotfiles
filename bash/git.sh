function git_gradle_hook {
    echo -n "Running gradle build: "
    GRADLE_OUTPUT=$( ${1:-"."}/gradlew --console=plain -q build 2>&1 >/dev/null )
    if [ $? -ne 0 ]; then
        echo "❌"
        echo "$GRADLE_OUTPUT"
        return 1;
    else
        echo "✔"
        return 0;
    fi
}